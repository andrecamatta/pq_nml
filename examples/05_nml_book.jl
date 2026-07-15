# Exemplo 5 — Pricing de NML pela matemática do livro (Castagna e Fede §7.7.1)
#
# Recalcula de forma independente o Exemplo 7.7.2 do livro e confere o resultado
# contra o valor publicado. Em seguida aplica a taxa justa d = αr (eq. 7.19) e o
# custo do buffer LBC (eq. 7.20) à poupança brasileira sob a regra dual, mostrando
# que o teto regulatório coloca o banco no caso de "forte poder de barganha" do
# livro (taxa paga abaixo de αr → funding spread zero → custo do buffer colapsa
# ao termo de caixa).

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQNML
using Printf

println("="^64)
println("Recálculo independente do Exemplo 7.7.2 (Castagna e Fede, §7.7.1)")
println("="^64)
r_book = 0.03
xd = daily_withdrawal_rate(0.05, 30)
fair = fair_nml_rate(r_book, 0.05, 30)
@printf "Taxa diária de saque x^d      : %.4f%%\n" 100 * xd
@printf "Taxa justa d = αr             : %.4f%% (risk-free = 3%%)\n" 100 * fair
res = nml_buffer_cost(nml0 = 100.0, x_nml = 0.05, nd = 30, r = r_book, rate_paid = fair + 0.02)
res_disc = nml_buffer_cost(nml0 = 100.0, x_nml = 0.05, nd = 30, r = r_book, rate_paid = fair + 0.02,
                           discount = i -> exp(-r_book * i / 365))
@printf "Funding spread s^B            : %.2f%%\n" 100 * res.funding_spread
@printf "LBC sem desconto              : %.4f (livro, texto: 0,1525)\n" res.lbc
@printf "LBC com desconto flat 3%%      : %.4f (livro, Tabela 7.18: 0,1523)\n" res_disc.lbc

println("\n", "="^64)
println("Aplicação à poupança brasileira (Selic = 14,5%, x = 5% a.m.)")
println("="^64)

selic = 0.145
r = selic                                    # risk-free de referência (Selic/CDI)
x_nml = 0.05                                 # runoff didático do exemplo do livro; o choque
                                             # de 5%/30d do LCR NÃO é taxa mensal recorrente
nd = 30
tr = 0.021                                   # TR ≈ 2,1% a.a. (SGS 226, jul/2026)
fair_br = fair_nml_rate(r, x_nml, nd)        # taxa justa de Castagna-Fede
paga = brazilian_savings_rate(selic; tr_annual = tr)  # taxa REGULADA (Lei 12.703/2012)
sB = nml_funding_spread(paga, r, x_nml, nd)
res_br = nml_buffer_cost(nml0 = 1.0, x_nml = x_nml, nd = nd, r = r, rate_paid = paga)
lbc_anual = res_br.lbc / (nd / 365)          # custo do buffer anualizado, fração do nominal

@printf "Taxa justa αr (livro)         : %.2f%%\n" 100 * fair_br
@printf "Taxa paga (TR + 0,5%% a.m.)    : %.2f%%\n" 100 * paga
@printf "Funding spread s^B            : %.2f%%   (zero: teto regulatório < αr)\n" 100 * sB
@printf "Custo do buffer (anualizado)  : %.4f%% do nominal\n" 100 * lbc_anual

println("\nLeitura: o teto da poupança congela a taxa paga muito abaixo da taxa justa")
println("αr de Castagna-Fede, então o banco está no caso de forte poder de barganha")
println("(s^B = 0). O custo do buffer reduz-se ao caixa contra saques diários, não ao")
println("spread de funding. É o resultado da Proposição 7.7.1 aplicado ao Brasil.")
println("\nPremissas fortes (o custo acima é limite inferior ilustrativo): r = Selic")
println("para todo o saldo, embora direcionamento (65% imobiliário) e compulsório")
println("reduzam o retorno marginal, e x = 5% a.m. didático, não calibrado à poupança.")
