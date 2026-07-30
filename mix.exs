defmodule Termite.MixProject do
  use Mix.Project

  @version "0.4.4"

  def project do
    [
      app: :termite,
      description: "A dependency-free NIF-free terminal library for Elixir.",
      package: package(),
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Termite",
      source_url: "https://github.com/Gazler/termite",
      docs: [
        source_ref: "v#{@version}",
        extras: [
          "README.md",
          "CHANGELOG.md"
        ]
      ]
    ]
  end

  def application do
    []
  end

  defp package() do
    [
      files: ~w(include lib .formatter.exs mix.exs README.md CHANGELOG.md LICENCE.md),
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
