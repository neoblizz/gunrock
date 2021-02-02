### sample python interface - pagerank

from ctypes import *

### load gunrock shared library - libgunrock
gunrock = cdll.LoadLibrary('../build/lib/libgunrock.so')
### read in input CSR arrays from files

labels = '../dataset/small/stars_2total_separate'
datatest = open(labels)

(line, dim) = datatest.readline().split()

print("number of lines ", line)
print("dimension ", dim)

array = [[int(x) for x in line.split()] for line in datatest]
print(array)

k = 5
epsilon = 1
min_pts = 1

print ('run gunrock')
### call gunrock function on device
elapsed = gunrock.snn(k, epsilon, min_pts)

### sample results
print ('elapsed: ' + str(elapsed))
