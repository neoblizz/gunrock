# ------------------------------------------------------------------------
#  Gunrock: Find FAISS directories
# ------------------------------------------------------------------------
FIND_LIBRARY( FAISS_LIBRARY
              NAMES faiss
              PATHS $ENV{FAISS_LIBRARY} )

FIND_PATH(  FAISS_INCLUDE_DIR
            NAMES faiss
            PATHS $ENV{FAISS_INCLUDE_DIR} )

IF (FAISS_LIBRARY)
    ADD_DEFINITIONS( -DFAISS_FOUND=1)
    INCLUDE_DIRECTORIES(${FAISS_INCLUDE_DIR})
    LINK_DIRECTORIES(${FAISS_INCLUDE_DIR}/build/faiss)
    LINK_DIRECTORIES(${FAISS_INCLUDE_DIR}/build/faiss/python)
    LINK_LIBRARIES( ${FAISS_LIBRARY} ${CUDA_CUBLAS_LIBRARIES})
ENDIF (FAISS_LIBRARY)
