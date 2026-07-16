# pq_nml

Pacote Julia que implementa modelagem comportamental de depósitos sem
vencimento (Non-Maturing Deposits, NMD) e o cálculo do Funds Transfer Pricing
com custo de liquidez. A notação NML é preservada nas fórmulas dos §§7.7 e
7.7.1 de Castagna e Fede (2013, *Measuring and Managing Liquidity Risk*).

Companion code do Artigo 4a da série sobre o Capítulo 7 (Pílulas de
Quant): "Non-Maturing Liabilities e o custo do buffer de liquidez no
pricing de depósitos".

## Escopo

Modela depósitos sem vencimento contratual e calcula:

- Modelo de runoff de Castagna e Fede (2013, §7.7): liquidez disponível
  AVL = NML(T0)(1−x)^N, funding gaps e estrutura a termo de funding.
- Pricing e custo econômico do buffer (§7.7.1): taxa diária de saque
  x^d = 1−(1−x)^(1/nd), taxa justa d* = αr com α = 1−x^d, funding spread
  s^B = max(d_paga−d*, 0) e custo do buffer LBC pela divisão caixa/ativo
  líquido somada dia a dia. O Exemplo 7.7.2 do livro é recalculado de
  forma independente e conferido contra os valores publicados.
- Alocação gerencial do custo regulatório: aproximação separada que aplica o
  runoff do LCR ao custo de carregar HQLA. Essa proxy não é tratada como a
  fórmula comportamental de Castagna e Fede.
- Regra dual da caderneta de poupança brasileira (Lei 12.703/2012):
  TR + 0,5% a.m. quando Selic > 8,5% a.a., TR + 70% × Selic caso
  contrário. Sob o teto, a taxa paga fica abaixo de αr e o spread s^B
  zera (caso de forte poder de barganha do livro).
- Replicating portfolio variance-minimizing (Kalkbrener e Willing,
  2004) como abordagem alternativa de mercado, com tranches de 1m a 10y
  e tracking error.
- Coleta de dados reais do Banco Central via API do SGS (captação líquida
  e saldo da poupança, meta Selic), para calibrar e validar com dados
  públicos em vez de cenários apenas sintéticos.

## Dados do Banco Central (SGS)

O módulo `bcb_data.jl` baixa séries reais do SGS do BCB (sem chave de API):

```julia
using PQNML, Dates

# Captação líquida anual da poupança (SBPE + rural), em R$ bilhões
funding = poupanca_net_funding(start_date = Date(2015,1,1), end_date = Date(2022,12,31))

# Saldo mensal da poupança (R$ milhões)
saldo = poupanca_saldo_mensal(start_date = Date(2024,1,1), end_date = Date(2024,1,31))

# Qualquer série pelo código SGS
selic = fetch_sgs(SGS_SELIC_META; start_date = Date(2024,1,1), end_date = Date(2024,12,31))
```

Séries usadas: `24` (captação líquida diária de poupança SBPE + rural, R$ mil),
`7836` (saldo mensal de poupança SBPE + rural, R$ milhões) e `432` (meta Selic,
% a.a.). O SGS não publica captação líquida mensal nem saldo mensal exclusivos do
SBPE, por isso as séries 24 e 7836 são SBPE + rural combinados. A captação líquida
mensal/anual é obtida somando a série diária.

## Instalação

```julia
] activate .
] instantiate
```

## Uso mínimo

```julia
using PQNML

# Simula Selic em torno de 11,5% por 60 meses
market = simulate_market(n_months = 60, scenario = :normal, selic_initial = 0.115)

# Aplica regra dual brasileira para gerar série de remuneração de poupança
deposit_rates = brazilian_savings_path(market.selic_path)

# Calibra replicating portfolio
rp = calibrate_replicating_portfolio(deposit_rates, market.selic_path)

# Produto: poupança SBPE com taxa de saída LCR de 5% em 30 dias (choque de estresse)
poupanca = NMDProduct(
    name = "Poupança",
    notional_initial = 1000.0,
    core_fraction = 0.85,
    lcr_runoff_30d = 0.05,
)

# FTP completo
summary_nmd(poupanca, market, rp, -0.005; capital_charge = 0.005)
```

## Exemplos

- `examples/01_savings_brazil.jl`: poupança sob regra dual em Selic 11,5%.
- `examples/02_stress_2015_2016.jl`: estresse de poupança no biênio 2015-2016.
- `examples/03_compare_products.jl`: comparação de proxies regulatórias de FTP entre categorias de NMD.
- `examples/04_fetch_bcb.jl`: baixa dados reais do BCB (SGS) e confere a captação líquida anual da poupança contra os números do artigo.
- `examples/05_nml_book.jl`: recalcula de forma independente o Exemplo 7.7.2 do livro, confere contra os valores publicados e aplica a taxa justa αr e o custo do buffer à poupança brasileira.

## Testes

```julia
] test
```

45 testes cobrindo: regra dual da poupança, taxa diária de saque, taxa
justa d* = αr, funding spread, custo do buffer (recalculado de forma
independente e conferido contra o Exemplo 7.7.2 do livro, com e sem
desconto), estrutura a termo de funding, calibração do replicating
portfolio e decomposição de runoff.

## Estrutura

```
src/
  PQNML.jl         # módulo principal
  types.jl         # NMDProduct, MarketScenario, ReplicatingPortfolio, FTPDecomposition
  rates.jl         # brazilian_savings_rate, brazilian_savings_path, simulate_market
  replicating.jl   # calibrate_replicating_portfolio, tracking_error, deposit_runoff_decomposition
  ftp.jl           # ftp_nmd, summary_nmd (decomposição de FTP, abordagem de mercado)
  nml_buffer.jl    # fair_nml_rate, nml_buffer_cost, nml_tsfu (§7.7/§7.7.1 do livro)
  bcb_data.jl      # fetch_sgs, poupanca_net_funding, poupanca_saldo_mensal (API SGS do BCB)
examples/
  01_savings_brazil.jl
  02_stress_2015_2016.jl
  03_compare_products.jl
  04_fetch_bcb.jl
  05_nml_book.jl
test/
  runtests.jl
```

## Referências

- CASTAGNA, A.; FEDE, F. *Measuring and Managing Liquidity Risk*. Wiley Finance, 2013. §7.7 e §7.7.1.
- JARROW, R. A.; VAN DEVENTER, D. R. The arbitrage-free valuation and hedging of demand deposits and credit card loans. *Journal of Banking & Finance*, v. 22, n. 3, 1998.
- KALKBRENER, M.; WILLING, J. Risk management of non-maturing liabilities. *Journal of Banking & Finance*, v. 28, n. 7, 2004.
- O'BRIEN, J. M. *Estimating the Value and Interest Rate Risk of Interest-Bearing Transactions Deposits*. FRB FEDS Working Paper 2000-53.
- BCBS. *Basel III: Liquidity Coverage Ratio* (BCBS 238), 2013.
- CIRCULAR BCB nº 3.749, de 5 de março de 2015.
- LEI nº 12.703, de 7 de agosto de 2012.

## Licença

MIT.
