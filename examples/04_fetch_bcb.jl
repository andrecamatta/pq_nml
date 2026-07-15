# Exemplo 4 — Coleta de dados reais do Banco Central (API SGS)
#
# Baixa a captação líquida da poupança (SBPE + rural) e o saldo mensal direto do SGS
# do BCB, agrega por ano e compara com os números citados no artigo. Requer rede.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQNML
using Dates

println("Baixando captação líquida da poupança (SGS série 24) ...")
funding = poupanca_net_funding(start_date = Date(2015, 1, 1), end_date = Date(2022, 12, 31))

println("\nCaptação líquida anual da poupança SBPE + rural (R\$ bilhões, fonte BCB/SGS):")
for (y, v) in funding
    println("  ", y, ": ", round(v, digits = 2))
end

# Valores reportados no artigo, para conferência de reprodutibilidade
esperado = Dict(2015 => -53.57, 2016 => -40.70, 2020 => 166.31, 2022 => -103.20)
println("\nConferência contra os valores citados no artigo:")
for y in sort(collect(keys(esperado)))
    real = first(v for (yy, v) in funding if yy == y)
    dif = real - esperado[y]
    println("  ", y, ": BCB = ", round(real, digits = 2),
            " | artigo = ", esperado[y],
            " | dif = ", round(dif, digits = 2))
end

println("\nBaixando saldo mensal da poupança (SGS série 7836) ...")
saldo = poupanca_saldo_mensal(start_date = Date(2024, 1, 1), end_date = Date(2024, 1, 31))
if !isempty(saldo)
    s = first(saldo)
    println("Saldo em ", s.date, ": R\$ ", round(s.value / 1_000, digits = 2), " bilhões (SBPE + rural)")
end

println("\nObservação: as séries 24 e 7836 são SBPE + rural combinados. Não há série")
println("de captação líquida só-SBPE nem de saldo mensal só-SBPE no SGS.")
