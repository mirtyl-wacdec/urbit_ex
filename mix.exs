defmodule UrbitEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :urbit_ex,
      version: "0.7.1",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "UrbitEx",
      description: "Elixir package to connect to a running Urbit instance",
      source_url: "https://github.com/mirtyl-wacdec/urbit_ex",
      package: package()
    ]
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "urbit_ex",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mirtyl-wacdec/urbit_ex"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
