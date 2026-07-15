"""
    NMDProduct

Produto de captação sem vencimento contratualmente definido (Non-Maturing
Deposit). Encapsula a regra de remuneração paga ao depositante e os
parâmetros comportamentais que descrevem como o saldo evolui em resposta
às condições de mercado.

# Campos
- `name`: identificação do produto
- `notional_initial`: saldo inicial em t=0
- `core_fraction`: fração estável (core) entre 0 e 1
- `decay_rate_annual`: taxa de saída anual em condições normais (decay)
- `runoff_stress_annual`: taxa de saída anual em estresse
- `lcr_runoff_30d`: taxa regulatória de saída em 30 dias (BCBS 238 / Circular BCB 3.749)
"""
Base.@kwdef struct NMDProduct
    name::String
    notional_initial::Float64
    core_fraction::Float64 = 0.85
    decay_rate_annual::Float64 = 0.05
    runoff_stress_annual::Float64 = 0.10
    lcr_runoff_30d::Float64 = 0.05
end

"""
    MarketScenario

Cenário de mercado com taxa risk-free (Selic, no Brasil) e duração da
janela de simulação em meses. Encapsula a função que calcula a taxa que
o produto paga ao depositante dado o nível de mercado.

# Campos
- `name`: identificação
- `selic_path`: vetor com Selic em cada mês
- `tr_path`: vetor com TR em cada mês (proxy de remuneração de poupança)
- `n_months`: número de meses simulados
"""
Base.@kwdef struct MarketScenario
    name::String
    selic_path::Vector{Float64}
    tr_path::Vector{Float64}
    n_months::Int
end

"""
    ReplicatingPortfolio

Portfólio replicante de tranches de bonds com pesos calibrados pelo
método variance-minimizing (Kalkbrener-Willing, 2004). Reproduz a
margem do NMD usando uma combinação estática de bonds zero-cupom de
prazos pré-definidos.

# Campos
- `tranches_months`: prazos das tranches (ex.: [1, 3, 6, 12, 36, 60, 120])
- `weights`: pesos não-negativos somando 1
- `tracking_error`: desvio-padrão da margem residual
"""
Base.@kwdef struct ReplicatingPortfolio
    tranches_months::Vector{Int}
    weights::Vector{Float64}
    tracking_error::Float64
end

"""
    FTPDecomposition

Decomposição do FTP de NMD em componentes conforme §7.7.1 de Castagna e
Fede (2013).

# Campos
- `replicating_yield`: rendimento médio do portfólio replicante
- `lb_cost`: custo do liquidity buffer atribuído ao produto
- `capital_charge`: charge de capital
- `service_credit`: crédito por serviços bancários (reduz FTP)
- `total_ftp`: soma dos componentes (líquido do crédito de serviços)
"""
Base.@kwdef struct FTPDecomposition
    replicating_yield::Float64
    lb_cost::Float64
    capital_charge::Float64
    service_credit::Float64 = 0.0
    total_ftp::Float64
end
