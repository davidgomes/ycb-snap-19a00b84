defmodule EctoJob.Supervisor do
  @moduledoc """
  Job Queue supervisor that can be started with client applications.

  The `EctoJob.Supervisor` will start the required processes to listen for postgres job notifications
  (when the repo uses `Ecto.Adapters.Postgres`), GenStage producer and ConsumerSupervisor to process the jobs.

  ## Example:

      def start(_type, _args) do
        import Supervisor.Spec

        children = [
          supervisor(MyApp.Repo, []),
          supervisor(MyApp.Endpoint, []),
          supervisor(EctoJob.Supervisor, [[
            name: MyAppJobQueue,
            app: :my_app,
            repo: MyApp.Repo,
            schema: MyApp.JobQueue,
            max_demand: 100]])
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end
  """

  import Supervisor.Spec, only: [worker: 2, supervisor: 2]
  alias EctoJob.{Config, Producer, WorkerSupervisor}

  @doc """
  Starts an EctoJob queue supervisor
  """
  @spec start_link(Config.t()) :: {:ok, pid}
  def start_link(
        config = %Config{
          repo: repo,
          schema: schema,
          max_demand: max_demand,
          poll_interval: poll_interval,
          reservation_timeout: reservation_timeout,
          execution_timeout: execution_timeout,
          notifications_listen_timeout: notifications_listen_timeout
        }
      ) do
    supervisor_name = String.to_atom("#{schema}.Supervisor")
    producer_name = String.to_atom("#{schema}.Producer")
    {notifier_name, notifier_children} = notifier(repo, schema)

    children = [
      worker(Producer, [
        [
          name: producer_name,
          repo: repo,
          schema: schema,
          notifier: notifier_name,
          poll_interval: poll_interval,
          reservation_timeout: reservation_timeout,
          execution_timeout: execution_timeout,
          notifications_listen_timeout: notifications_listen_timeout
        ]
      ]),
      supervisor(WorkerSupervisor, [
        [config: config, subscribe_to: [{producer_name, max_demand: max_demand}]]
      ])
    ]

    Supervisor.start_link(notifier_children ++ children,
      strategy: :rest_for_one,
      name: supervisor_name
    )
  end

  # New job notifications rely on Postgres LISTEN/NOTIFY, other adapters only poll for jobs.
  @spec notifier(module, module) :: {atom | nil, [Supervisor.Spec.spec()]}
  defp notifier(repo, schema) do
    if repo.__adapter__() == Ecto.Adapters.Postgres do
      notifier_name = String.to_atom("#{schema}.Notifier")
      {notifier_name, [worker(Postgrex.Notifications, [repo.config() ++ [name: notifier_name]])]}
    else
      {nil, []}
    end
  end
end
