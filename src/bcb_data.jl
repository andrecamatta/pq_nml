# bcb_data.jl — coleta de séries reais do Banco Central do Brasil via API pública do SGS
#
# Sistema Gerenciador de Séries Temporais (SGS): https://api.bcb.gov.br/dados/serie
# Endpoint: bcdata.sgs.{codigo}/dados?formato=json[&dataInicial=dd/mm/aaaa&dataFinal=dd/mm/aaaa]
#
# Códigos usados (confirmados no SGS, fonte Abecip e BCB-Depec):
#   24   Captação líquida diária de depósitos de poupança - SBPE e rural (R$ mil)
#   7836 Saldo mensal de depósitos de poupança - SBPE e rural (R$ milhões)
#   432  Meta da taxa Selic definida pelo Copom (% a.a.)
#
# Observação metodológica: o BCB não publica captação líquida MENSAL no SGS. A série de
# captação é diária (cód. 24); o total mensal/anual é obtido somando os valores diários.

const SGS_BASE_URL = "https://api.bcb.gov.br/dados/serie/bcdata.sgs"

const SGS_POUPANCA_CAPTACAO = 24    # captação líquida diária (R$ mil), SBPE + rural
const SGS_POUPANCA_SALDO     = 7836  # saldo mensal (R$ milhões), SBPE + rural
const SGS_SELIC_META         = 432   # meta Selic (% a.a.)

"""
    SGSObservation

Uma observação de série temporal do SGS: data e valor na unidade nativa da série.
"""
struct SGSObservation
    date::Date
    value::Float64
end

"""
    fetch_sgs(code; start_date = nothing, end_date = nothing) -> Vector{SGSObservation}

Baixa a série SGS de código `code` da API do Banco Central. Quando `start_date` e
`end_date` (objetos `Date`) são informados, restringe o intervalo. Valores ausentes
no SGS (string vazia) viram `NaN`.

Requer conexão de rede. Lança erro se o download ou o parsing falharem.
"""
function fetch_sgs(code::Integer; start_date::Union{Date,Nothing} = nothing,
                                  end_date::Union{Date,Nothing} = nothing)::Vector{SGSObservation}
    url = "$(SGS_BASE_URL).$(code)/dados?formato=json"
    if start_date !== nothing && end_date !== nothing
        di = Dates.format(start_date, dateformat"dd/mm/yyyy")
        df = Dates.format(end_date, dateformat"dd/mm/yyyy")
        url *= "&dataInicial=$(di)&dataFinal=$(df)"
    end
    raw = sprint() do io
        Downloads.download(url, io)
    end
    return parse_sgs_json(raw)
end

"""
    parse_sgs_json(raw) -> Vector{SGSObservation}

Faz o parsing da resposta JSON do SGS. O payload é um vetor plano e regular de objetos
`{"data":"dd/mm/aaaa","valor":"x.xx"}`, o que permite extração robusta sem dependência
de biblioteca JSON externa.
"""
function parse_sgs_json(raw::AbstractString)::Vector{SGSObservation}
    obs = SGSObservation[]
    pattern = r"\"data\"\s*:\s*\"(\d{2}/\d{2}/\d{4})\"\s*,\s*\"valor\"\s*:\s*\"(-?\d*\.?\d*)\""
    for m in eachmatch(pattern, raw)
        d = Date(m.captures[1], dateformat"dd/mm/yyyy")
        v = isempty(m.captures[2]) ? NaN : parse(Float64, m.captures[2])
        push!(obs, SGSObservation(d, v))
    end
    isempty(obs) && error("Resposta do SGS sem observações reconhecíveis. Verifique o código da série e a conexão.")
    return obs
end

"""
    annual_net_funding(obs) -> Vector{Pair{Int,Float64}}

Agrega a captação líquida diária (série 24, em R\$ mil) em totais anuais expressos em
R\$ bilhões. Retorna pares `ano => valor` ordenados por ano.
"""
function annual_net_funding(obs::Vector{SGSObservation})::Vector{Pair{Int,Float64}}
    acc = Dict{Int,Float64}()
    for o in obs
        isnan(o.value) && continue
        acc[year(o.date)] = get(acc, year(o.date), 0.0) + o.value
    end
    return sort([y => v / 1_000_000 for (y, v) in acc])  # R$ mil -> R$ bilhões
end

"""
    poupanca_net_funding(; start_date, end_date) -> Vector{Pair{Int,Float64}}

Conveniência: baixa a captação líquida diária da poupança (SBPE + rural) e devolve os
totais anuais em R\$ bilhões para o intervalo pedido.
"""
function poupanca_net_funding(; start_date::Date = Date(2015, 1, 1),
                                end_date::Date = Date(2022, 12, 31))::Vector{Pair{Int,Float64}}
    obs = fetch_sgs(SGS_POUPANCA_CAPTACAO; start_date = start_date, end_date = end_date)
    return annual_net_funding(obs)
end

"""
    poupanca_saldo_mensal(; start_date, end_date) -> Vector{SGSObservation}

Baixa o saldo mensal de poupança (SBPE + rural, série 7836) já em R\$ milhões.
"""
function poupanca_saldo_mensal(; start_date::Date = Date(2024, 1, 1),
                                 end_date::Date = Date(2024, 12, 31))::Vector{SGSObservation}
    return fetch_sgs(SGS_POUPANCA_SALDO; start_date = start_date, end_date = end_date)
end
