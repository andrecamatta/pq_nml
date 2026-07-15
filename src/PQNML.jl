module PQNML

using LinearAlgebra
using Printf
using Statistics
using Dates
using Downloads

include("types.jl")
include("rates.jl")
include("replicating.jl")
include("ftp.jl")
include("nml_buffer.jl")
include("bcb_data.jl")

export NMDProduct, MarketScenario, ReplicatingPortfolio, FTPDecomposition
export brazilian_savings_rate, brazilian_savings_path
export simulate_market, calibrate_replicating_portfolio
export tracking_error, deposit_runoff_decomposition
export ftp_nmd, summary_nmd
# §7.7 / §7.7.1 (Castagna e Fede) — modelo fiel ao livro
export daily_withdrawal_rate, fair_nml_rate, nml_funding_spread
export nml_available_funding, nml_buffer_cost, nml_tsfu, LBCResult
export SGSObservation, fetch_sgs, annual_net_funding
export poupanca_net_funding, poupanca_saldo_mensal
export SGS_POUPANCA_CAPTACAO, SGS_POUPANCA_SALDO, SGS_SELIC_META

end # module
