
using Logging
using DiffEqBase
using Sundials

using Plots

import PALEOboxes as PB
import PALEOmodel
import PALEOocean
import PALEOcopse


global_logger(ConsoleLogger(stderr, Logging.Info))

include("config_ocean3box_expts.jl")
include("plot_ocean_3box.jl")

# Open atmosphere-ocean with silicate carbonate weathering input and carbonate burial
model = PB.create_model_from_config(
    joinpath(@__DIR__, "PALEO_examples_ocean3box_cfg.yaml"), "ocean3box_oaopencarb_base")

config_ocean3box_expts(model, ["killbio", "lowO2"]); tspan=(-1e6, 1e6) # tspan=(-10e6, 10e6)

initial_state, modeldata = PALEOmodel.initialize!(model)
statevar_norm = PALEOmodel.get_statevar_norm(modeldata.solver_view_all)

# call ODE function to check derivative
println("initial_state", initial_state)
println("statevar_norm", statevar_norm)
initial_deriv = similar(initial_state)
PALEOmodel.SolverFunctions.ModelODE(modeldata)(initial_deriv, initial_state , nothing, 0.0)
println("initial_deriv", initial_deriv)

paleorun = PALEOmodel.Run(model=model, output=PALEOmodel.OutputWriters.OutputMemory())

# With `killbio` H2S goes to zero, so this provides a test case for solvers `abstol` handling
# (without this option, solver will fail or take excessive steps as it attempts to solve H2S for noise) 

# Solve as DAE with (sparse) Jacobian
PALEOmodel.ODE.integrateDAEForwardDiff(
   paleorun, initial_state, modeldata, tspan,
   alg=IDA(linear_solver=:KLU),
   solvekwargs=(
      abstol=1e-6*PALEOmodel.get_statevar_norm(modeldata.solver_view_all), # required to handle H2S -> 0.0
      save_start=false
   )
)

# Solve as ODE with Jacobian (OK if no carbonate chem or global temperature)
# sol = PALEOmodel.ODE.integrateForwardDiff(paleorun, initial_state, modeldata, tspan, alg=CVODE_BDF(linear_solver=:KLU))
#    solvekwargs=(abstol=1e-6*PALEOmodel.get_statevar_norm(modeldata.solver_view_all),))


########################################
# Plot output
########################################

# individual plots
# plotlyjs(size=(750, 565))
# pager = PALEOmodel.DefaultPlotPager()

# assemble plots onto screens with 6 subplots
gr(size=(1200, 900))

pager=PALEOmodel.PlotPager((2, 3), (legend_background_color=nothing, ))

plot_totals(paleorun.output; species=["C", "TAlk", "TAlkerror", "O2", "S", "P"], pager=pager)
plot_ocean_tracers(
    paleorun.output; 
    tracers=["TAlk_conc", "DIC_conc", "temp", "pHtot", "O2_conc", "SO4_conc", "H2S_conc", "P_conc", 
        "SO4_delta", "H2S_delta", "pHtot", "OmegaAR"],
    pager=pager
)
plot_oaonly_abiotic(paleorun.output; pager=pager)
plot_carb_open(paleorun.output; pager=pager)
pager(:newpage) # flush output
