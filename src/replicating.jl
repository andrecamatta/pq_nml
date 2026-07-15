"""
    bond_yield_at(maturity_months, selic_annual)

Aproximação simples do yield de um bond zero-cupom no Brasil dado o
prazo em meses e a Selic vigente. Usa estrutura a termo plana com leve
prêmio por prazo.
"""
function bond_yield_at(maturity_months::Int, selic_annual::Float64)
    term_premium = 0.001 * sqrt(maturity_months / 12)
    return selic_annual + term_premium
end

"""
    portfolio_yield(weights, tranches_months, selic_path)

Yield mensal do portfólio replicante dada a Selic vigente. Usa aproximação
estática em que cada tranche rende seu yield contemporâneo ponderado pelo
peso correspondente.
"""
function portfolio_yield(
    weights::Vector{Float64},
    tranches_months::Vector{Int},
    selic_path::Vector{Float64},
)
    n = length(selic_path)
    yields = Vector{Float64}(undef, n)
    for t in 1:n
        y = 0.0
        for (w, m) in zip(weights, tranches_months)
            y += w * bond_yield_at(m, selic_path[t])
        end
        yields[t] = y
    end
    return yields
end

"""
    calibrate_replicating_portfolio(deposit_rates, selic_path; tranches_months)

Calibra o portfólio replicante minimizando a variância da margem
(yield_portfolio − deposit_rate) sob restrições de não-negatividade e
soma dos pesos igual a 1.

Implementa uma versão simplificada do método de Kalkbrener e Willing
(2004) e Maes e Timmermans (2005) usando regressão linear restrita
resolvida por mínimos quadrados via método de gradiente projetado.
"""
function calibrate_replicating_portfolio(
    deposit_rates::Vector{Float64},
    selic_path::Vector{Float64};
    tranches_months::Vector{Int} = [1, 3, 6, 12, 36, 60, 120],
)
    n = length(deposit_rates)
    k = length(tranches_months)

    # Matriz de yields por tranche em cada período
    Y = Matrix{Float64}(undef, n, k)
    for t in 1:n, j in 1:k
        Y[t, j] = bond_yield_at(tranches_months[j], selic_path[t])
    end

    # Inicializa com pesos uniformes (a matriz Y'Y pode ser singular quando
    # tranches têm yields colineares em cenários de Selic constante)
    w = fill(1.0 / k, k)

    # Refina via descida de gradiente projetado
    lr = 0.01
    for iter in 1:500
        residual = Y * w .- deposit_rates
        grad = 2 * Y' * residual
        w = w .- lr * grad
        w = max.(w, 0.0)
        if sum(w) > 0
            w = w ./ sum(w)
        end
    end

    # Tracking error
    yields_rp = Y * w
    margin = yields_rp .- deposit_rates
    te = std(margin)

    return ReplicatingPortfolio(
        tranches_months = tranches_months,
        weights = w,
        tracking_error = te,
    )
end

"""
    tracking_error(rp, deposit_rates, selic_path)

Recalcula o tracking error (desvio-padrão da margem) para um portfólio
replicante dado um caminho de mercado e uma série de taxas de depósito.
"""
function tracking_error(
    rp::ReplicatingPortfolio,
    deposit_rates::Vector{Float64},
    selic_path::Vector{Float64},
)
    yields_rp = portfolio_yield(rp.weights, rp.tranches_months, selic_path)
    margin = yields_rp .- deposit_rates
    return std(margin)
end

"""
    deposit_runoff_decomposition(product, market)

Decompõe o saldo do depósito em core (estável) e non-core (volátil)
e projeta a evolução em estresse. Usa o `core_fraction` declarado no
produto e aplica `runoff_stress_annual` ao non-core.
"""
function deposit_runoff_decomposition(product::NMDProduct, market::MarketScenario)
    n = market.n_months
    core_balance = Vector{Float64}(undef, n + 1)
    noncore_balance = Vector{Float64}(undef, n + 1)
    total_balance = Vector{Float64}(undef, n + 1)

    core_balance[1] = product.notional_initial * product.core_fraction
    noncore_balance[1] = product.notional_initial * (1 - product.core_fraction)
    total_balance[1] = product.notional_initial

    monthly_decay_core = 1 - (1 - product.decay_rate_annual)^(1/12)
    monthly_runoff_noncore = 1 - (1 - product.runoff_stress_annual)^(1/12)

    for t in 1:n
        core_balance[t + 1] = core_balance[t] * (1 - monthly_decay_core)
        noncore_balance[t + 1] = noncore_balance[t] * (1 - monthly_runoff_noncore)
        total_balance[t + 1] = core_balance[t + 1] + noncore_balance[t + 1]
    end

    return (core = core_balance, noncore = noncore_balance, total = total_balance)
end
