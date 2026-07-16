"""
    ftp_nmd(product, rp, hqla_yield_spread, selic_current; capital_charge = 0.005, service_credit = 0.0)

Calcula uma decomposição gerencial de FTP para um produto NMD. O custo de liquidez
é uma aproximação regulatória baseada no runoff do LCR e no custo de carregar HQLA.
Essa aproximação é distinta do custo econômico comportamental de Castagna e Fede,
implementado por `nml_buffer_cost`.

# Argumentos
- `product`: NMDProduct com classificação core/non-core e runoff regulatório
- `rp`: ReplicatingPortfolio calibrado
- `hqla_yield_spread`: spread negativo entre yield de HQLA e custo do funding (tipicamente −0,3% a −0,8%)
- `selic_current`: Selic vigente para cálculo do yield do replicating portfolio
- `capital_charge`: charge de capital (KVA) sobre o produto
- `service_credit`: crédito por serviços bancários (reduz o FTP)

# Fórmula gerencial com alocação proporcional do custo regulatório
FTP_NMD = r_RF(replicating) + s_LB + s_capital − s_serviços
onde s_LB = c_HQLA × runoff_rate (LCR aplicado proporcional)
"""
function ftp_nmd(
    product::NMDProduct,
    rp::ReplicatingPortfolio,
    hqla_yield_spread::Float64,
    selic_current::Float64;
    capital_charge::Float64 = 0.005,
    service_credit::Float64 = 0.0,
)
    # Yield do portfólio replicante na Selic atual
    rp_yield = sum(rp.weights .* [bond_yield_at(m, selic_current) for m in rp.tranches_months])

    # Custo do LB anualizado em pontos sobre o nominal do NMD.
    # O banco mantém HQLA proporcional à fração de runoff em 30 dias
    # sobre o saldo do NMD ao longo de todo o ano. O custo de carrego
    # é o spread negativo (hqla_yield − funding_cost) aplicado a essa
    # parcela. Convencionalmente expresso como fração do nominal:
    # lb_cost = runoff_30d × |hqla_yield_spread|
    lb_cost = product.lcr_runoff_30d * abs(hqla_yield_spread)

    total = rp_yield + lb_cost + capital_charge - service_credit

    return FTPDecomposition(
        replicating_yield = rp_yield,
        lb_cost = lb_cost,
        capital_charge = capital_charge,
        service_credit = service_credit,
        total_ftp = total,
    )
end

"""
    summary_nmd(product, market, rp, hqla_yield_spread; capital_charge = 0.005)

Imprime relatório completo do produto NMD: classificação, runoff,
calibração do replicating portfolio, decomposição do FTP.
"""
function summary_nmd(
    product::NMDProduct,
    market::MarketScenario,
    rp::ReplicatingPortfolio,
    hqla_yield_spread::Float64;
    capital_charge::Float64 = 0.005,
)
    println("="^72)
    println("Análise de NMD — $(product.name)")
    println("="^72)
    @printf "Saldo inicial: %.2f\n" product.notional_initial
    @printf "Fração core: %.1f%%\n" 100 * product.core_fraction
    @printf "Decay rate (normal): %.2f%% a.a.\n" 100 * product.decay_rate_annual
    @printf "Runoff (estresse): %.2f%% a.a.\n" 100 * product.runoff_stress_annual
    @printf "LCR runoff 30d: %.2f%%\n\n" 100 * product.lcr_runoff_30d

    println("Replicating portfolio (Kalkbrener-Willing variance-minimizing):")
    for (m, w) in zip(rp.tranches_months, rp.weights)
        @printf "  Tranche %3d meses: peso = %5.1f%%\n" m 100 * w
    end
    @printf "  Tracking error: %.6f\n\n" rp.tracking_error

    selic_current = market.selic_path[end]
    decomp = ftp_nmd(product, rp, hqla_yield_spread, selic_current;
                     capital_charge = capital_charge)
    println("Decomposição do FTP em Selic = $(round(100*selic_current, digits=2))%:")
    @printf "  Replicating yield     : %.4f (%.2f%%)\n" decomp.replicating_yield 100*decomp.replicating_yield
    @printf "  Custo do LB           : %.4f (%.2f%%)\n" decomp.lb_cost 100*decomp.lb_cost
    @printf "  Capital charge        : %.4f (%.2f%%)\n" decomp.capital_charge 100*decomp.capital_charge
    @printf "  Crédito de serviços   : %.4f (%.2f%%)\n" decomp.service_credit 100*decomp.service_credit
    @printf "  ─────────────────────────────────\n"
    @printf "  FTP total             : %.4f (%.2f%%)\n" decomp.total_ftp 100*decomp.total_ftp

    println("\nProjeção de saldo em cenário de estresse:")
    decomp_balance = deposit_runoff_decomposition(product, market)
    months_to_show = [1, 6, 12, 24, 36, 60]
    for m in months_to_show
        if m <= market.n_months
            @printf "  t = %3d meses → core %.2f, non-core %.2f, total %.2f\n" m decomp_balance.core[m+1] decomp_balance.noncore[m+1] decomp_balance.total[m+1]
        end
    end

    println("="^72)
    return decomp
end
