# The basis definition
@variables u[1:2]
basis = Basis([polynomial_basis(u, 5); sin.(u); cos.(u)], u)

function pendulum(u, p, t)
    x = u[2]
    y = -9.81sin(u[1]) - 0.1u[2]^3 - 0.2 * cos(u[1])
    return [x;y]
end

u0 = [0.99π; -1.0]
tspan = (0.0, 20.0)
dt = 0.1
prob = ODEProblem(pendulum, u0, tspan)
sol = solve(prob, Tsit5(), saveat=dt)

X = sol[:,:]
t = sol.t

##
@testset "Ideal data" begin
    dd_prob = ContinuousDataDrivenProblem(
        sol
        )


    opts = [
    STLSQ(1e-2), ADMM(1e-2, 1e-2), SR3(1e-2, SoftThreshold()),
    SR3(1e-4)
    ]

    for opt in opts
        res = solve(dd_prob, basis, opt, maxiter = 50000)
        m = DataDrivenDiffEq.metrics(res)
        @test all(m[:L₂] .< 1e-1*size(X, 2))
        @test all(m[:AIC] .<= 200.0) 
        @test all(m[:R²] .>= 0.9)
    end
    
end


Random.seed!(1234)
X_n = X .+ 1e-1*randn(size(X))

@testset "Noisy data" begin

    dd_prob_noisy = ContinuousDataDrivenProblem(
        X_n, t, GaussianKernel()
        )

    
    opts = [
            STLSQ(1e-1:5e-1:1e3), ADMM(1e-1:5e-1:1e5, 1.0), SR3(1e-1:5e-1:1e5, 2.0, SoftThreshold()),
            SR3((1e-1:5e-1:1e5), 2.0, HardThreshold()), SR3(1e-3:5e-1:1e5, 2.0, ClippedAbsoluteDeviation())
        ]



    for opt in opts
        res = solve(dd_prob_noisy, basis, opt, maxiter = 50000, denoise = true, normalize = true)
        m = DataDrivenDiffEq.metrics(res)
        @show m
        @test all(m[:L₂] .< [30.; 800.0])
        @test all(m[:AIC] .< 1400.0)
        @test all(m[:R²] .>= [0.9; 0.5])
    end

end
