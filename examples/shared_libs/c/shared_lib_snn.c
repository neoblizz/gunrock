/**
 * @brief SNN test for shared library advanced interface
 * @file shared_lib_snn.c
 */

#include <stdio.h>
#include <gunrock/gunrock.h>

int main(int argc, char *argv[]) {
  ////////////////////////////////////////////////////////////////////////////

  int k = 4;
  int eps = 5;
  int min_pts = 5;

  char* labels = "../dataset/small/stars_2total_separate";
  int items_scanned = 0, num_labels = 0, dim = 0;

  FILE *f_in = fopen(labels, "r");
  if (!f_in) {
      printf("file does not exist %s\n", labels);
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
  int* clusters_counter = (int*) malloc(sizeof(int));       clusters_counter[0] = 0;
  int* noise_points_counter = (int*) malloc(sizeof(int));   noise_points_counter[0] = 0;
  int* core_points_counter = (int*) malloc(sizeof(int));    core_points_counter[0] = 0;

  double elapsed = snn(labels, &k, &eps, &min_pts, clusters, clusters_counter, 
  core_points_counter, noise_points_counter);

  return 0;
}
