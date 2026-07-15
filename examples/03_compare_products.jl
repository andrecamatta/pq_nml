# Exemplo 3 — Comparação de FTP entre poupança, CDB com FGC e CDB sem FGC
#
# Mostra como produtos com perfis comportamentais distintos resultam em
# FTPs diferentes, mesmo sob a mesma Selic vigente.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQNML
using Printf

market = simulate_market(n_months = 36, scenario = :normal, selic_initial = 0.115)
deposit_rates_savings = brazilian_savings_path(market.selic_path)
rp_savings = calibrate_replicating_portfolio(deposit_rates_savings, market.selic_path)

# Para CDB com FGC: behavior próximo a poupança mas runoff mais alto
deposit_rates_cdb_fgc = market.selic_path .* 0.95  # 95% do CDI
rp_cdb_fgc = calibrate_replicating_portfolio(deposit_rates_cdb_fgc, market.selic_path)

# CDB sem FGC (atacado): comportamento muito mais volátil
deposit_rates_cdb_atacado = market.selic_path .* 1.05  # 105% do CDI
rp_cdb_atacado = calibrate_replicating_portfolio(deposit_rates_cdb_atacado, market.selic_path)

products = [
    (NMDProduct(name = "Poupança", notional_initial = 1000.0,
                core_fraction = 0.85, lcr_runoff_30d = 0.05), rp_savings),
    (NMDProduct(name = "CDB c/ FGC (varejo)", notional_initial = 1000.0,
                core_fraction = 0.70, lcr_runoff_30d = 0.10), rp_cdb_fgc),
    (NMDProduct(name = "CDB s/ FGC (atacado)", notional_initial = 1000.0,
                core_fraction = 0.40, lcr_runoff_30d = 0.40), rp_cdb_atacado),
]

selic_current = 0.115
println("="^72)
@printf "Comparação de FTP para Selic = %.1f%% a.a.\n" 100*selic_current
println("="^72)
@printf "%-25s %-12s %-12s %-12s %-12s\n" "Produto" "RP yield" "LB cost" "Capital" "FTP total"
println("-"^75)

for (p, rp) in products
    decomp = ftp_nmd(p, rp, -0.005, selic_current; capital_charge = 0.005)
    @printf "%-25s %-12.4f %-12.4f %-12.4f %-12.4f\n" p.name decomp.replicating_yield decomp.lb_cost decomp.capital_charge decomp.total_ftp
end

println("\nNote como o LB cost cresce com a taxa de saída do LCR de cada produto.")
println("O CDB de atacado sem FGC tem custo de carrego do buffer ~8x maior")
println("que a poupança, refletindo a maior volatilidade comportamental.")
