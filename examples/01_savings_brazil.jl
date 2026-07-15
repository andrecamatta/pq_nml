# Exemplo 1 — Poupança brasileira sob regra dual (Lei 12.703/2012)
#
# Demonstra a calibração de um replicating portfolio para a poupança
# brasileira em um cenário de Selic em torno de 11,5% a.a., onde a
# remuneração é fixada em TR + 0,5% a.m. (≈ TR + 6,17% a.a.).

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQNML

# Cenário: Selic em torno de 11,5%, mercado normal
market = simulate_market(n_months = 60, scenario = :normal, selic_initial = 0.115)
deposit_rates = brazilian_savings_path(market.selic_path)

# Calibra o replicating portfolio (Kalkbrener-Willing)
rp = calibrate_replicating_portfolio(deposit_rates, market.selic_path)

# Produto: poupança SBPE estilizada
poupanca = NMDProduct(
    name = "Caderneta de Poupança SBPE",
    notional_initial = 1000.0,
    core_fraction = 0.85,
    decay_rate_annual = 0.05,
    runoff_stress_annual = 0.10,
    lcr_runoff_30d = 0.05,
)

# Spread HQLA negativo: yield TPF aprox = Selic; custo de funding = Selic + spread
hqla_spread = -0.005  # 50 bps de carrego negativo

summary_nmd(poupanca, market, rp, hqla_spread; capital_charge = 0.005)
