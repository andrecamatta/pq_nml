"""
    brazilian_savings_rate(selic_annual; tr_annual = 0.0)

Calcula a remuneração anual da caderneta de poupança brasileira segundo
a regra dual estabelecida pela Lei 12.703/2012.

- Se Selic > 8,5% a.a.: 0,5% a.m. composto com a TR (com TR nula, ≈ 6,17% a.a.)
- Se Selic ≤ 8,5% a.a.: TR + 70% × Selic (a TR é aproximadamente nula nesse regime)

A regra cria uma função não-linear da Selic com break em 8,5%, central
para a calibração de modelos comportamentais aplicados ao depósito de
poupança.
"""
function brazilian_savings_rate(selic_annual::Float64; tr_annual::Float64 = 0.0)
    if selic_annual > 0.085
        return (1 + 0.005)^12 * (1 + tr_annual) - 1  # 0,5% a.m. composto com a TR
    else
        return tr_annual + 0.70 * selic_annual
    end
end

"""
    brazilian_savings_path(selic_path; tr_path = nothing)

Aplica a regra dual mês a mês a um caminho de Selic, retornando o vetor
de remunerações nominais anuais da poupança em cada período.
"""
function brazilian_savings_path(selic_path::Vector{Float64}; tr_path = nothing)
    if tr_path === nothing
        tr_path = zeros(length(selic_path))
    end
    return [brazilian_savings_rate(s, tr_annual = t) for (s, t) in zip(selic_path, tr_path)]
end

"""
    simulate_market(; n_months, selic_initial, selic_break, scenario)

Gera um caminho determinístico de Selic para simular cenários típicos
do mercado brasileiro. Cenários:
- `:normal`: Selic em torno de 10% a.a. com pequenas oscilações
- `:tightening`: Selic sobe de 8,5% para 13,75% (similar a 2021-2022)
- `:easing`: Selic cai de 13,75% para 8,5% (similar a 2023-2024)
- `:stress`: Selic disparada com inflação alta (similar a 2015-2016)
"""
function simulate_market(;
    n_months::Int = 60,
    selic_initial::Float64 = 0.10,
    scenario::Symbol = :normal,
)
    selic_path = Vector{Float64}(undef, n_months)
    if scenario == :normal
        selic_path .= selic_initial
        for i in 1:n_months
            selic_path[i] = selic_initial + 0.005 * sin(2π * i / 12)
        end
    elseif scenario == :tightening
        for i in 1:n_months
            selic_path[i] = 0.085 + (0.1375 - 0.085) * min(i / 24, 1.0)
        end
    elseif scenario == :easing
        for i in 1:n_months
            selic_path[i] = 0.1375 - (0.1375 - 0.085) * min(i / 24, 1.0)
        end
    elseif scenario == :stress
        for i in 1:n_months
            selic_path[i] = 0.10 + 0.04 * (i / n_months) + 0.01 * randn()
        end
    end
    tr_path = max.(selic_path .- 0.10, 0.0) .* 0.4
    return MarketScenario(
        name = "Cenário $(scenario)",
        selic_path = selic_path,
        tr_path = tr_path,
        n_months = n_months,
    )
end
