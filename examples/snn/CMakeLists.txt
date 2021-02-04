# ------------------------------------------------------------------------
#  Gunrock: Sub-Project Shared Nearest Neighbor
# ------------------------------------------------------------------------
project(snn)
message("-- Project Added: ${PROJECT_NAME}")
include(${CMAKE_SOURCE_DIR}/cmake/SetSubProject.cmake)

target_link_libraries(${PROJECT_NAME} ${CUDA_cudadevrt_LIBRARY})

if (FAISS_LIBRARY)
    target_link_libraries(${PROJECT_NAME} ${FAISS_LIBRARY})
    target_link_libraries(${PROJECT_NAME} ${FAISS_INCLUDE_DIR}/build/faiss/python/_swigfaiss.so)
    target_link_libraries(${PROJECT_NAME} ${CUDA_CUBLAS_LIBRARIES})
endif (FAISS_LIBRARY)

add_test(NAME TEST_SNN COMMAND snn market --labels-file
  ${gunrock_INCLUDE_DIRS}/dataset/small/stars_2total_separate --k=2 --eps=1 --min-pts=1)
set_tests_properties(TEST_SNN PROPERTIES PASS_REGULAR_EXPRESSION "PASSED SNN")
