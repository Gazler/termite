defmodule Termite.MixProject do
  use Mix.Project

  def project do
    [
      app: :termite,
      description: "A dependency-free NIF-free terminal library for Elixir.",
      package: package(),
      version: "0.2.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENCE.md),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Gazler/termite"}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
