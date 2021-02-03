/**
 * @brief SNN test for shared library advanced interface
 * @file shared_lib_snn.c
 */

#include <stdio.h>
#include <gunrock/gunrock.h>

int main(int argc, char *argv[]) {
  ////////////////////////////////////////////////////////////////////////////
/*
  int num_labels = 10, dim = 3;

  int labels[10*3] = {7, 3, 1,
                      19, 3, 1,
                      6, 2, 1,
                      7, 2, 1,
                      8, 2, 1,
                      18, 2, 1,
                      19, 2, 1,
                      20, 2, 1,
                      7, 1, 1,
                      19, 1, 1};
  
  */

  int num_nodes = 7, num_edges = 26;
  int row_offsets[8] = {0, 3, 6, 11, 15, 19, 23, 26};
  int col_indices[26] = {1, 2, 3, 0, 2, 4, 0, 1, 3, 4, 5, 0, 2,
                         5, 6, 1, 2, 5, 6, 2, 3, 4, 6, 3, 4, 5};

  int *node_ids = (int *)malloc(sizeof(int) * num_nodes);
  float *ranks = (float *)malloc(sizeof(float) * num_nodes);
  //double elapsed2 = pagerank(num_nodes, num_edges, row_offsets, col_indices, 1,
  //                          node_ids, ranks);
  
  int k = 30;
  int eps = 5;
  int min_pts = 5;

  char* labels = "../dataset/small/stars_2total_separate";
  int items_scanned = 0, num_labels = 0, dim = 0;

  FILE *f_in = fopen(labels, "r");
  if (!f_in) {
      printf("file does not exist\n");
      return 0;
  }

  char line[1024];
  while(true){
    if (fscanf(f_in, "%[^\n]\n", line) <= 0){
        break;
    }
    if (line[0] == '%' || line[0] == '#'){
        continue;
    }
    items_scanned = sscanf(line, "%lld %lld", &num_labels, &dim);
    fclose(f_in);
    break;
  }

  if (items_scanned != 2){
      printf("There is %d items in the first line\n", items_scanned);
      printf("File format problem, first line format is <num_labels> <dim>\n");
      return 0;
  }else{
      printf("Read number of points and dim: %d, %d\n", num_labels, dim);
  }

  int* clusters = (int*) malloc(sizeof(int)*num_labels);
  int clusters_counter = 0, noise_points_counter = 0, core_points_counter = 0;

  double elapsed = snn(labels, k, eps, min_pts, clusters, clusters_counter, 
  core_points_counter, noise_points_counter);

  return 0;
}
