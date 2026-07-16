# nml_buffer.jl — modelo de NML de Castagna e Fede (2013), §7.7 e §7.7.1
#
# Implementa fielmente a abordagem do livro Measuring and Managing Liquidity Risk:
#   §7.7   — runoff x_NML% por subperíodo, rollovers fictícios, survival periods,
#            term structure of available funding (TSFu) e funding gaps. Eq. (7.17).
#   §7.7.1 — taxa diária de saque, taxa justa paga no NML d = α·r (eq. 7.19),
#            funding spread s^B = max(d − αr, 0) e custo do buffer LBC (eq. 7.20/7.21),
#            decompondo o buffer em caixa (rende 0) e ativo líquido (rende risk-free).
#
# A validação está em test/runtests.jl: o custo do buffer é recalculado de forma
# independente com os parâmetros do Exemplo 7.7.2 (x=5% a.m., 30 dias, r=3%, s^B=2%,
# NML=100) e conferido contra os valores publicados no livro (0,1525 no texto, sem
# desconto; 0,1523 na Tabela 7.18, com desconto).

"""
    daily_withdrawal_rate(x_nml, nd) -> Float64

Taxa diária de saque consistente com o runoff `x_nml` do período de sobrevivência de
`nd` dias (eq. 7.16 do livro): x^d = 1 − (1 − x_NML)^(1/nd).
"""
daily_withdrawal_rate(x_nml::Real, nd::Integer) = 1 - (1 - x_nml)^(1 / nd)

"""
    fair_nml_rate(r, x_nml, nd) -> Float64

Taxa justa que o banco deveria pagar no NML, eq. (7.19): d = α·r, com α = 1 − x^d.
Como a fração de caixa x^d não rende, a taxa justa é o risk-free reduzido por essa
fração. Resolve a condição de indiferença (7.18) entre juros pagos e retorno dos
ativos líquidos financiados pelo NML.
"""
function fair_nml_rate(r::Real, x_nml::Real, nd::Integer)
    α = 1 - daily_withdrawal_rate(x_nml, nd)
    return α * r
end

"""
    nml_funding_spread(rate_paid, r, x_nml, nd) -> Float64

Funding spread do NML, s^B = max(rate_paid − α·r, 0). Se o banco tem poder de barganha
suficiente para pagar a taxa justa α·r (ou menos), o spread é zero. Competição ou
barganha fraca empurram a taxa paga acima de α·r e geram spread positivo.
"""
function nml_funding_spread(rate_paid::Real, r::Real, x_nml::Real, nd::Integer)
    return max(rate_paid - fair_nml_rate(r, x_nml, nd), 0.0)
end

"""
    nml_available_funding(nml0, x_nml, n) -> Float64

Liquidez disponível para investimento ao fim de `n` subperíodos, eq. (7.17):
AVL_NL = NML(T₀)(1 − x_NML)^n. O complemento NML(T₀) − AVL é a soma dos funding
gaps acumulados até o horizonte; ele não deve ser interpretado automaticamente como
o estoque de buffer mantido em cada data.
"""
nml_available_funding(nml0::Real, x_nml::Real, n::Integer) = nml0 * (1 - x_nml)^n

"""
    LBCResult

Resultado do custo do buffer de liquidez de um ativo financiado por NML (§7.7.1):
- `lbc`: custo total do buffer no período (eq. 7.20), em unidades de nominal
- `cash_term`: parcela do caixa que não rende, remunerada a (r + s^B)
- `lasset_term`: parcela do ativo líquido, remunerada ao spread s^B
- `fair_rate`: taxa justa α·r (eq. 7.19)
- `funding_spread`: s^B efetivo usado no cálculo
"""
Base.@kwdef struct LBCResult
    lbc::Float64
    cash_term::Float64
    lasset_term::Float64
    fair_rate::Float64
    funding_spread::Float64
end

"""
    nml_buffer_cost(; nml0, x_nml, nd, r, rate_paid, lb_end = 0.0, beta = 0.0,
                      discount = identity_discount) -> LBCResult

Custo do buffer de liquidez para um ativo financiado por NML em um período de
sobrevivência de `nd` dias, eq. (7.20)/(7.21) do livro. O buffer se divide a cada dia
entre caixa (cobre o saque esperado, rende 0) e ativo líquido (rende risk-free). O
custo é a soma diária descontada de:
  (r + s^B)·Caixa_i + s^B·AtivoLíquido_i,  i = 1..nd
mais o termo β·s^B·LB_fim·τ quando o buffer remanescente no fim do período (`lb_end`)
é positivo.

`rate_paid` é a taxa efetivamente paga no NML; o spread s^B = max(rate_paid − αr, 0) é
derivado internamente. `discount(i)` é o fator de desconto P^D(0, T_i) para o dia i
(padrão: 1, isto é, sem desconto, como na ilustração do livro).
"""
function nml_buffer_cost(; nml0::Real, x_nml::Real, nd::Integer, r::Real,
                           rate_paid::Real, lb_end::Real = 0.0, beta::Real = 0.0,
                           discount = (i -> 1.0))::LBCResult
    xd = daily_withdrawal_rate(x_nml, nd)
    sB = nml_funding_spread(rate_paid, r, x_nml, nd)
    avl = nml_available_funding(nml0, x_nml, 1)   # funding disponível após o runoff do período

    cash_term = 0.0
    lasset_term = 0.0
    for i in 1:nd
        outstanding = avl * (1 - xd)^i
        cash_i = outstanding * xd                 # saque esperado mantido em caixa
        lasset_i = outstanding * (1 - xd)         # parcela em ativo líquido
        cash_term += discount(i) * (r + sB) * cash_i / 365
        lasset_term += discount(i) * sB * lasset_i / 365
    end

    τ = nd / 365
    lb_term = beta * sB * lb_end * τ

    return LBCResult(
        lbc = lb_term + cash_term + lasset_term,
        cash_term = cash_term,
        lasset_term = lasset_term,
        fair_rate = fair_nml_rate(r, x_nml, nd),
        funding_spread = sB,
    )
end

"""
    nml_tsfu(nml0, x_nml, n_periods) -> NamedTuple

Term structure of available funding para NML (§7.7), reproduzindo a lógica das
Tabelas 7.14 e 7.16. Retorna, para cada subperíodo n = 1..n_periods:
- `funding_gap`: FG(T_n) = x_NML·NML(T₀)(1 − x_NML)^(n−1)
- `forward_cumulated`: FCAVL_NL = NML(T₀)(1 − x_NML)^n (funding disponível à frente)
"""
function nml_tsfu(nml0::Real, x_nml::Real, n_periods::Integer)
    fg = [x_nml * nml0 * (1 - x_nml)^(n - 1) for n in 1:n_periods]
    fcavl = [nml0 * (1 - x_nml)^n for n in 1:n_periods]
    return (funding_gap = fg, forward_cumulated = fcavl)
end
