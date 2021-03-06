// ----------------------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// ----------------------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// ----------------------------------------------------------------------------

/**
 * @file color_app.cu
 *
 * @brief Graph Coloring Gunrock Application
 */

#include <gunrock/gunrock.h>

// Utilities and correctness-checking
#include <gunrock/util/test_utils.cuh>

// Graph definitions
#include <gunrock/app/app_base.cuh>
#include <gunrock/app/test_base.cuh>
#include <gunrock/graphio/graphio.cuh>

// Graph Coloring
#include <gunrock/app/color/color_enactor.cuh>
#include <gunrock/app/color/color_test.cuh>

// Others
#include <cstdio>

namespace gunrock {
namespace app {
namespace color {

cudaError_t UseParameters(util::Parameters &parameters) {
  cudaError_t retval = cudaSuccess;
  GUARD_CU(UseParameters_app(parameters));
  GUARD_CU(UseParameters_problem(parameters));
  GUARD_CU(UseParameters_enactor(parameters));
  GUARD_CU(UseParameters_test(parameters));

  GUARD_CU(parameters.Use<unsigned int>(
        "num-colors",
        util::REQUIRED_ARGUMENT | util::SINGLE_VALUE | util::INTERNAL_PARAMETER,
        0, "number of output colors", __FILE__, __LINE__));

  GUARD_CU(parameters.Use<int>(
      "seed", util::REQUIRED_ARGUMENT | util::OPTIONAL_PARAMETER, time(NULL),
      "seed for random number generator", __FILE__, __LINE__));

  return retval;
}

/**
 * @brief Run color tests
 * @tparam     GraphT        Type of the graph
 * @tparam     ValueT        Type of the distances
 * @param[in]  parameters    Excution parameters
 * @param[in]  graph         Input graph
...
 * @param[in]  target        where to perform the app
 * \return cudaError_t error message(s), if any
 */
template <typename GraphT>
cudaError_t RunTests(util::Parameters &parameters, GraphT &graph,
                     typename GraphT::VertexT *ref_colors,
                     util::Location target) {
  cudaError_t retval = cudaSuccess;

  typedef typename GraphT::VertexT VertexT;
  typedef typename GraphT::ValueT ValueT;
  typedef typename GraphT::SizeT SizeT;
  typedef Problem<GraphT> ProblemT;
  typedef Enactor<ProblemT> EnactorT;

  // CLI parameters
  bool quiet_mode = parameters.Get<bool>("quiet");
  int num_runs = parameters.Get<int>("num-runs");
  std::string validation = parameters.Get<std::string>("validation");
  util::Info info("color", parameters, graph);

  util::CpuTimer cpu_timer, total_timer;
  cpu_timer.Start();
  total_timer.Start();

  VertexT *h_colors = new VertexT[graph.nodes];

  // Allocate problem and enactor on GPU, and initialize them
  ProblemT problem(parameters);
  EnactorT enactor;
  GUARD_CU(problem.Init(graph, target));
  GUARD_CU(enactor.Init(problem, target));

  cpu_timer.Stop();
  parameters.Set("preprocess-time", cpu_timer.ElapsedMillis());
  int num_colors = 0;
  for (int run_num = 0; run_num < num_runs; ++run_num) {
    GUARD_CU(problem.Reset(target));
    GUARD_CU(enactor.Reset(target));

    util::PrintMsg("__________________________", !quiet_mode);

    cpu_timer.Start();
    GUARD_CU(enactor.Enact());
    cpu_timer.Stop();
    info.CollectSingleRun(cpu_timer.ElapsedMillis());

    util::PrintMsg(
        "--------------------------\nRun " + std::to_string(run_num) +
            " elapsed: " + std::to_string(cpu_timer.ElapsedMillis()) +
            ", #iterations = " +
            std::to_string(enactor.enactor_slices[0].enactor_stats.iteration),
        !quiet_mode);
    if (validation == "each") {
      GUARD_CU(problem.Extract(h_colors));
      SizeT num_errors = Validate_Results(parameters, graph, h_colors,
                                          ref_colors, false);
    }
  }

  cpu_timer.Start();

  GUARD_CU(problem.Extract(h_colors));
  if (validation == "last") {
    SizeT num_errors = Validate_Results(parameters, graph, h_colors, ref_colors,
                                        false);
  }

  // count number of colors
  std::unordered_set<int> set;
  for (SizeT v = 0; v < graph.nodes; v++) {
    int c = h_colors[v];
    if (set.find(c) == set.end()) {
      set.insert(c);
      num_colors++;
    }
  }
  
  util::PrintMsg("Number of colors needed: " + num_colors, !quiet_mode);
  parameters.Set("num-colors", num_colors);
  
  // compute running statistics
  info.ComputeTraversalStats(enactor, (VertexT *)NULL);
// Display_Memory_Usage(problem);
#ifdef ENABLE_PERFORMANCE_PROFILING
  // Display_Performance_Profiling(&enactor);
#endif

  // Clean up
  GUARD_CU(enactor.Release(target));
  GUARD_CU(problem.Release(target));
  delete[] h_colors;
  h_colors = NULL;
  cpu_timer.Stop();
  total_timer.Stop();

  info.Finalize(cpu_timer.ElapsedMillis(), total_timer.ElapsedMillis());
  return retval;
}

}  // namespace color
}  // namespace app
}  // namespace gunrock

/*
 * @brief Entry of gunrock_color function
 * @tparam     GraphT     Type of the graph
 * @tparam     VertexT    Type of the colors
 * @param[in]  parameters Excution parameters
 * @param[in]  graph      Input graph
 * @param[out] colors     Return generated colors for each run
 * @param[out] num_colors Return number of colors generated for each run
 * \return     double     Return accumulated elapsed times for all runs
 */
template <typename GraphT, typename VertexT = typename GraphT::VertexT,
          typename SizeT = typename GraphT::SizeT>
double gunrock_color(gunrock::util::Parameters &parameters, GraphT &graph,
                     VertexT **colors, SizeT *num_colors) {
  typedef gunrock::app::color::Problem<GraphT> ProblemT;
  typedef gunrock::app::color::Enactor<ProblemT> EnactorT;
  gunrock::util::CpuTimer cpu_timer;
  gunrock::util::Location target = gunrock::util::DEVICE;
  double total_time = 0;
  if (parameters.UseDefault("quiet")) parameters.Set("quiet", true);

  // Allocate problem and enactor on GPU, and initialize them
  ProblemT problem(parameters);
  EnactorT enactor;
  problem.Init(graph, target);
  enactor.Init(problem, target);

  int num_runs = parameters.Get<int>("num-runs");
  for (int run_num = 0; run_num < num_runs; ++run_num) {
    problem.Reset(target);
    enactor.Reset(target);

    cpu_timer.Start();
    enactor.Enact();
    cpu_timer.Stop();

    total_time += cpu_timer.ElapsedMillis();
    problem.Extract(colors[run_num]);

    // count number of colors
    std::unordered_set<int> set;
    for (SizeT v = 0; v < graph.nodes; v++) {
      int c = colors[run_num][v];
      if (set.find(c) == set.end()) {
        set.insert(c);
        num_colors[run_num] += 1;
      }
    }
  }

  enactor.Release(target);
  problem.Release(target);
  return total_time;
}

/*
 * @brief Entry of gunrock_color function
 * @tparam     VertexT    Type of the colors
 * @tparam     SizeT      Type of the num_colors
 * @param[in]  parameters Excution parameters
 * @param[in]  graph      Input graph
 * @param[out] colors     Return generated colors for each run
 * @param[out] num_colors Return number of colors generated for each run
 * \return     double     Return accumulated elapsed times for all runs
 */
template <typename VertexT, typename SizeT>
double color(const SizeT num_nodes, const SizeT num_edges,
             const SizeT *row_offsets, const VertexT *col_indices,
             int **colors, int *num_colors, const int num_runs) {
  typedef typename gunrock::app::TestGraph<VertexT, SizeT, VertexT,
                                           gunrock::graph::HAS_CSR> GraphT;
  typedef typename GraphT::CsrT CsrT;

  // Setup parameters
  gunrock::util::Parameters parameters("color");
  gunrock::graphio::UseParameters(parameters);
  gunrock::app::color::UseParameters(parameters);
  gunrock::app::UseParameters_test(parameters);
  parameters.Parse_CommandLine(0, NULL);
  parameters.Set("graph-type", "by-pass");
  parameters.Set("num-runs", num_runs);

  bool quiet = parameters.Get<bool>("quiet");
  GraphT graph;
  // Assign pointers into gunrock graph format
  graph.CsrT::Allocate(num_nodes, num_edges, gunrock::util::HOST);
  graph.CsrT::row_offsets.SetPointer((SizeT *)row_offsets, num_nodes + 1,
                                     gunrock::util::HOST);
  graph.CsrT::column_indices.SetPointer((VertexT *)col_indices, num_edges,
                                        gunrock::util::HOST);
  graph.FromCsr(graph.csr(), gunrock::util::HOST, 0, quiet, true);
  gunrock::graphio::LoadGraph(parameters, graph);

  // Run the graph coloring
  double elapsed_time = gunrock_color(parameters, graph, colors, num_colors);

  // Cleanup
  graph.Release();

  return elapsed_time;
}

/*
 * @brief Entry of gunrock_color function
 * @tparam     VertexT    Type of the colors
 * @tparam     SizeT      Type of the num_colors
 * @param[in]  parameters Excution parameters
 * @param[in]  graph      Input graph
 * @param[out] colors     Return generated colors for each run
 * @param[out] num_colors Return number of colors generated for each run
 * \return     double     Return accumulated elapsed times for all runs
 */
double color(const int num_nodes, const int num_edges, const int *row_offsets,
             const int *col_indices, int *colors, int num_colors) {
  return color(num_nodes, num_edges, row_offsets, col_indices,
               &colors, &num_colors, 1 /* num_runs */);
}

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
