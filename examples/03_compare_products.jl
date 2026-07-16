# Exemplo 3 — Comparação de proxies regulatórias de FTP entre categorias de NMD
#
# Mostra o efeito do peso de runoff de LCR sobre a proxy regulatória de FTP.
# A classificação regulatória é uma entrada; não estima a estabilidade comportamental.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQNML
using Printf

market = simulate_market(n_months = 36, scenario = :normal, selic_initial = 0.115)
deposit_rates_savings = brazilian_savings_path(market.selic_path)
rp_savings = calibrate_replicating_portfolio(deposit_rates_savings, market.selic_path)

# Conta remunerada hipotética a 95% da Selic, apenas para comparação didática.
deposit_rates_remunerated = market.selic_path .* 0.95
rp_remunerated = calibrate_replicating_portfolio(deposit_rates_remunerated, market.selic_path)

products = [
    (NMDProduct(name = "Poupança varejo estável", notional_initial = 1000.0,
                core_fraction = 0.85, lcr_runoff_30d = 0.05), rp_savings),
    (NMDProduct(name = "Conta varejo menos estável", notional_initial = 1000.0,
                core_fraction = 0.70, lcr_runoff_30d = 0.10), rp_remunerated),
    (NMDProduct(name = "Conta com saldo agregado elevado", notional_initial = 1000.0,
                core_fraction = 0.70, lcr_runoff_30d = 0.20), rp_remunerated),
]

selic_current = 0.115
println("="^78)
@printf "Comparação de proxies de FTP para Selic = %.1f%% a.a.\n" 100*selic_current
println("="^78)
@printf "%-34s %-11s %-11s %-11s %-11s\n" "Categoria" "RP yield" "LB cost" "Capital" "FTP total"
println("-"^82)

for (product, rp) in products
    decomp = ftp_nmd(product, rp, -0.005, selic_current; capital_charge = 0.005)
    @printf "%-34s %-11.4f %-11.4f %-11.4f %-11.4f\n" product.name decomp.replicating_yield decomp.lb_cost decomp.capital_charge decomp.total_ftp
end

println("\nLeitura:")
println("  O custo de buffer desta função cresce com o peso regulatório informado.")
println("  A estabilidade comportamental deve ser calibrada separadamente: o runoff")
println("  de LCR não é, por si só, uma estimativa de saídas recorrentes ou de estresse.")
