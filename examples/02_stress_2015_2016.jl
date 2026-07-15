# Exemplo 2 — Estresse de poupança 2015-2016 (Selic > 14%)
#
# Reproduz o evento empírico em que a poupança brasileira teve saída
# líquida agregada de R$ 94 bi em 2 anos (2015: −53,57 bi; 2016: −40,7 bi)
# sob Selic > 14% a.a.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQNML

market = simulate_market(n_months = 24, scenario = :stress, selic_initial = 0.14)
deposit_rates = brazilian_savings_path(market.selic_path)

println("Cenário: Selic mensal em estresse (proxy 2015-2016)")
println("Selic média do período: ", round(100 * sum(market.selic_path) / length(market.selic_path), digits = 2), "%")

rp = calibrate_replicating_portfolio(deposit_rates, market.selic_path)

# Poupança em estresse: saída anual bem acima do decaimento de períodos calmos
poupanca_stress = NMDProduct(
    name = "Poupança SBPE (cenário 2015-2016)",
    notional_initial = 1000.0,
    core_fraction = 0.75,
    decay_rate_annual = 0.05,
    runoff_stress_annual = 0.15,  # estresse bruto ASSUMIDO; a captação líquida do
                                  # biênio foi ≈7% a.a. e subestima o saque bruto
    lcr_runoff_30d = 0.05,
)

summary_nmd(poupanca_stress, market, rp, -0.005; capital_charge = 0.008)

println("\nNota: a captação líquida do biênio (≈7% a.a.) compensa saques com depósitos")
println("novos e por isso subestima o saque bruto; calibrar runoff exigiria coortes ou")
println("as séries separadas de depósitos e retiradas. O choque do LCR (5% em 30 dias)")
println("é cenário de estresse pontual, não comparável a uma taxa anual observada.")
