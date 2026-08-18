# Paginator

[![Build status](https://github.com/duffelhq/paginator/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/duffelhq/paginator/actions?query=branch%3Amain)
[![Inline docs](http://inch-ci.org/github/duffelhq/paginator.svg)](http://inch-ci.org/github/duffelhq/paginator)
[![Module Version](https://img.shields.io/hexpm/v/paginator.svg)](https://hex.pm/packages/paginator)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/paginator/)
[![Total Download](https://img.shields.io/hexpm/dt/paginator.svg)](https://hex.pm/packages/paginator)
[![License](https://img.shields.io/hexpm/l/paginator.svg)](https://github.com/duffelhq/paginator/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/duffelhq/paginator.svg)](https://github.com/duffelhq/paginator/commits/master)

[Cursor based pagination](http://use-the-index-luke.com/no-offset) for Elixir [Ecto](https://github.com/elixir-ecto/ecto).

## Why?

There are several ways to implement pagination in a project and they all have pros and cons depending on your situation.

### Limit-offset

This is the easiest method to use and implement: you just have to set `LIMIT` and `OFFSET` on your queries and the
database will return records based on this two parameters. Unfortunately, it has two major drawbacks:

* Inconsistent results: if the dataset changes while you are querying, the results in the page will shift and your user
might end seeing records they have already seen and missing new ones.

* Inefficiency: `OFFSET N` instructs the database to skip the first N results of a query. However, the database must still
fetch these rows from disk and order them before it can returns the ones requested. If the dataset you are querying is
large this will result in significant slowdowns.

### Cursor-based (a.k.a keyset pagination)

This method relies on opaque cursor to figure out where to start selecting records. It is more performant than
`LIMIT-OFFSET` because it can filter records without traversing all of them.

It's also consistent, any insertions/deletions before the current page will leave results unaffected.

It has some limitations though: for instance you can't jump directly to a specific page. This may
not be an issue for an API or if you use infinite scrolling on your website.

### Learn more

* http://use-the-index-luke.com/no-offset
* http://use-the-index-luke.com/sql/partial-results/fetch-next-page
* https://www.citusdata.com/blog/2016/03/30/five-ways-to-paginate/
* https://developer.twitter.com/en/docs/tweets/timelines/guides/working-with-timelines

## Getting started

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end

query = from(p in Post, order_by: [asc: p.inserted_at, asc: p.id])

page = MyApp.Repo.paginate(query, cursor_fields: [:inserted_at, :id], limit: 50)

# `page.entries` contains all the entries for this page.
# `page.metadata` contains the metadata associated with this page (cursors, limit, total count)
```

## Installation

Add `:paginator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:paginator, "~> 1.2.0"}
  ]
end
```

## Usage

Add `Paginator` to your repo:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
```

Use the `paginate` function to paginate your queries:

```elixir
query = from(p in Post, order_by: [asc: p.inserted_at, asc: p.id])

# return the first 50 posts
%{entries: entries, metadata: metadata}
  = Repo.paginate(
    query,
    cursor_fields: [:inserted_at, :id],
    limit: 50
  )

# assign the `after` cursor to a variable
cursor_after = metadata.after

# return the next 50 posts
%{entries: entries, metadata: metadata}
  = Repo.paginate(
    query,
    after: cursor_after,
    cursor_fields: [{:inserted_at, :asc}, {:id, :asc}],
    limit: 50
  )

# assign the `before` cursor to a variable
cursor_before = metadata.before

# return the previous 50 posts (if no post was created in between it should be
# the same list as in our first call to `paginate`)
%{entries: entries, metadata: metadata}
  = Repo.paginate(
    query,
    before: cursor_before,
    cursor_fields: [:inserted_at, :id],
    limit: 50
  )

# return total count
# NOTE: this will issue a separate `SELECT COUNT(*) FROM table` query to the
# database.
%{entries: entries, metadata: metadata}
  = Repo.paginate(
    query,
    include_total_count: true,
    cursor_fields: [:inserted_at, :id],
    limit: 50
  )

IO.puts "total count: #{metadata.total_count}"
```

### Paginating on an expression

Sometimes the value a query sorts on is computed rather than stored in a
column, so it can't be named in `:cursor_fields`. For those cases a cursor
field can be given as `{key, fn -> dynamic(...) end}`: the function builds the
expression the pagination filters compare against, and `key` is the name the
value is stored under in the cursor.

```elixir
payment_counts =
  from(p in Payment,
    group_by: p.customer_id,
    select: %{customer_id: p.customer_id, count: count(p.id)}
  )

query =
  from(c in Customer,
    left_join: pc in subquery(payment_counts),
    on: pc.customer_id == c.id,
    as: :payment_counts,
    select_merge: %{payment_count: coalesce(pc.count, 0)},
    order_by: [{:asc, coalesce(pc.count, 0)}, {:asc, c.id}]
  )

%{entries: entries, metadata: metadata} =
  Repo.paginate(
    query,
    cursor_fields: [
      {{:payment_count, fn -> dynamic([payment_counts: pc], coalesce(pc.count, 0)) end}, :asc},
      id: :asc
    ],
    limit: 50
  )
```

Since the expression is not a column, Paginator can't read its value off the
returned records on its own. Either select it into a field of the same name as
the key, as above with the `:payment_count` virtual field, or pass a
`:fetch_cursor_value_fun` that knows how to look it up.

Note that the expression ends up in a `WHERE` clause, so it has to be valid
there. Aggregates such as `count(p.id)` are not, which is why the example above
computes the count in a subquery it joins on.

## Security Considerations

`Repo.paginate/4` will throw an `ArgumentError` should it detect an executable term in the cursor parameters passed to it (`before`, `after`).
This is done to protect you from potential side-effects of malicious user input, see [paginator_test.exs](https://github.com/duffelhq/paginator/blob/master/test/paginator_test.exs#L820).

## Indexes

If you want to reap all the benefits of this method it is better that you create indexes on the columns you are using as
cursor fields.

### Example

```elixir
# If your cursor fields are: [:inserted_at, :id]
# Add the following in a migration

create index("posts", [:inserted_at, :id])
```

## Caveats

* This method requires a deterministic sort order. If the columns you are currently using for sorting don't match that
definition, just add any unique column and extend your index accordingly.
* You need to add `:order_by` clauses yourself before passing your query to `paginate/2`. In the future we might do that
for you automatically based on the fields specified in `:cursor_fields`.
* There is an outstanding issue where Postgrex fails to properly builds the query if it includes custom PostgreSQL types.
* This library has only be tested with PostgreSQL.

## Documentation

Documentation is written into the library, you will find it in the source code, accessible from `iex` and of course, it
all gets published to [hexdocs](http://hexdocs.pm/paginator).

## Contributing

### Running tests

Clone the repo and fetch its dependencies:

```
$ git clone https://github.com/duffelhq/paginator.git
$ cd paginator
$ mix deps.get
$ mix test
```

### Building docs

```
$ mix docs
```

## Copyright and License

Copyright (c) 2017 Steve Domin.

This software is licensed under [the MIT license](./LICENSE.md).
