using Test
using PQNML

@testset "PQNML" begin

    @testset "Regra dual da poupança brasileira" begin
        # Selic > 8,5%: TR + 0,5% a.m. ≈ 6,17% a.a.
        rate_high = brazilian_savings_rate(0.10)
        @test rate_high ≈ (1.005)^12 - 1 atol=1e-6

        # Selic ≤ 8,5%: 70% × Selic
        rate_low = brazilian_savings_rate(0.06)
        @test rate_low ≈ 0.7 * 0.06

        # Break em 8,5%
        rate_break = brazilian_savings_rate(0.085)
        @test rate_break ≈ 0.7 * 0.085

        # TR não-zero: composta com o 0,5% a.m.
        rate_with_tr = brazilian_savings_rate(0.10, tr_annual = 0.01)
        @test rate_with_tr ≈ (1.005)^12 * 1.01 - 1 atol=1e-10

        # Selic ≤ 8,5%: a TR também é composta com a remuneração adicional
        rate_low_with_tr = brazilian_savings_rate(0.06, tr_annual = 0.01)
        @test rate_low_with_tr ≈ 1.01 * (1 + 0.70 * 0.06) - 1 atol=1e-10
    end

    @testset "Path de poupança" begin
        selic = [0.10, 0.09, 0.08, 0.07]
        rates = brazilian_savings_path(selic)
        @test length(rates) == 4
        # Os dois primeiros usam regra TR + 0,5%; os dois últimos usam 70% × Selic
        @test rates[1] > rates[3]
    end

    @testset "Construção de tipos" begin
        p = NMDProduct(name = "Poupança", notional_initial = 1000.0,
                       core_fraction = 0.85, decay_rate_annual = 0.05)
        @test p.notional_initial == 1000.0
        @test p.core_fraction == 0.85
    end

    @testset "Simulação de mercado" begin
        m = simulate_market(n_months = 24, scenario = :tightening)
        @test m.n_months == 24
        @test length(m.selic_path) == 24
        # Em tightening, último valor > primeiro
        @test m.selic_path[end] > m.selic_path[1]
    end

    @testset "Replicating portfolio" begin
        m = simulate_market(n_months = 36, scenario = :normal, selic_initial = 0.10)
        deposit_rates = brazilian_savings_path(m.selic_path)
        rp = calibrate_replicating_portfolio(deposit_rates, m.selic_path)
        @test sum(rp.weights) ≈ 1.0 atol=1e-3
        @test all(rp.weights .>= -1e-6)
        @test rp.tracking_error >= 0
    end

    @testset "Decomposição de runoff" begin
        p = NMDProduct(name = "Test", notional_initial = 1000.0,
                       core_fraction = 0.8, decay_rate_annual = 0.05,
                       runoff_stress_annual = 0.15)
        m = simulate_market(n_months = 12, scenario = :stress)
        decomp = deposit_runoff_decomposition(p, m)
        # Saldo total decresce monotonicamente
        for t in 1:12
            @test decomp.total[t + 1] <= decomp.total[t]
        end
        # Non-core decresce mais rápido que core
        ratio_t12 = decomp.noncore[13] / decomp.noncore[1]
        ratio_core_t12 = decomp.core[13] / decomp.core[1]
        @test ratio_t12 < ratio_core_t12
    end

    @testset "FTP positivo e razoável" begin
        p = NMDProduct(name = "Poupança BR", notional_initial = 1000.0,
                       lcr_runoff_30d = 0.05)
        m = simulate_market(n_months = 36, scenario = :normal, selic_initial = 0.115)
        deposit_rates = brazilian_savings_path(m.selic_path)
        rp = calibrate_replicating_portfolio(deposit_rates, m.selic_path)
        decomp = ftp_nmd(p, rp, -0.005, 0.115; capital_charge = 0.005)
        @test decomp.total_ftp > 0
        @test decomp.replicating_yield > 0
        @test decomp.lb_cost > 0
    end

    @testset "Taxa diária de saque (eq. 7.16)" begin
        # Exemplo 7.7.2: x=5% a.m., 30 dias → x^d ≈ 0,17%
        xd = daily_withdrawal_rate(0.05, 30)
        @test xd ≈ 1 - (1 - 0.05)^(1 / 30) atol = 1e-10
        @test xd ≈ 0.0017089 atol = 1e-6
    end

    @testset "Taxa justa d = αr (eq. 7.19)" begin
        # Exemplo 7.7.2: r=3%, x=5%, 30 dias → d ≈ 2,995%
        d = fair_nml_rate(0.03, 0.05, 30)
        @test d ≈ 0.03 * (1 - daily_withdrawal_rate(0.05, 30)) atol = 1e-12
        @test d ≈ 0.02995 atol = 1e-4
        @test d < 0.03   # taxa justa é fração do risk-free
    end

    @testset "Funding spread s^B = max(d − αr, 0)" begin
        # Pagar exatamente a taxa justa → spread zero (banco com barganha)
        fair = fair_nml_rate(0.03, 0.05, 30)
        @test nml_funding_spread(fair, 0.03, 0.05, 30) ≈ 0.0 atol = 1e-12
        # Pagar acima da justa → spread positivo
        @test nml_funding_spread(fair + 0.02, 0.03, 0.05, 30) ≈ 0.02 atol = 1e-10
    end

    @testset "Custo do buffer LBC (eq. 7.20) — Exemplo 7.7.2 do livro" begin
        # Recálculo independente com NML=100, x=5% a.m., 30 dias, r=3%, s^B=2%,
        # conferido contra os dois valores publicados no livro:
        # 0,1525 no texto (sem desconto) e 0,1523 na Tabela 7.18 (com desconto).
        fair = fair_nml_rate(0.03, 0.05, 30)
        res = nml_buffer_cost(nml0 = 100.0, x_nml = 0.05, nd = 30, r = 0.03,
                              rate_paid = fair + 0.02)
        @test res.funding_spread ≈ 0.02 atol = 1e-10
        @test res.lbc ≈ 0.1525 atol = 1e-4
        res_disc = nml_buffer_cost(nml0 = 100.0, x_nml = 0.05, nd = 30, r = 0.03,
                                   rate_paid = fair + 0.02,
                                   discount = i -> exp(-0.03 * i / 365))
        @test res_disc.lbc ≈ 0.1523 atol = 1e-4
        # O termo de ativo líquido domina o termo de caixa
        @test res.lasset_term > res.cash_term
    end

    @testset "TSFu de NML (§7.7) — Tabela 7.16" begin
        # NML=100, x=5%, soma de funding gaps reconstrói o esgotamento do saldo
        ts = nml_tsfu(100.0, 0.05, 24)
        @test ts.forward_cumulated[1] ≈ 95.0 atol = 1e-9   # FCAVL após 1 mês
        @test ts.forward_cumulated[24] ≈ 100 * (1 - 0.05)^24 atol = 1e-9  # ≈ 29,20
        @test ts.funding_gap[1] ≈ 5.0 atol = 1e-9          # primeiro gap = x·NML
    end

end
