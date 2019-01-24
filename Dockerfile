# An integration test & dev container which builds and installs cuDF from master
ARG CUDA_VERSION=9.2
ARG LINUX_VERSION=ubuntu16.04
FROM nvidia/cuda:${CUDA_VERSION}-devel-${LINUX_VERSION}
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64:/usr/local/lib
# Needed for pygdf.concat(), avoids "OSError: library nvvm not found"
ENV NUMBAPRO_NVVM=/usr/local/cuda/nvvm/lib64/libnvvm.so
ENV NUMBAPRO_LIBDEVICE=/usr/local/cuda/nvvm/libdevice/

ARG CC=5
ARG CXX=5
RUN apt update -y --fix-missing && \
    apt upgrade -y && \
    apt install -y \
      git \
      gcc-${CC} \
      g++-${CXX} \
      libboost-all-dev

# Install conda
ADD https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh /miniconda.sh
RUN sh /miniconda.sh -b -p /conda && /conda/bin/conda update -n base conda
ENV PATH=${PATH}:/conda/bin
# Enables "source activate conda"
SHELL ["/bin/bash", "-c"]

# Build cuDF conda env
ARG PYTHON_VERSION
ENV PYTHON_VERSION=$PYTHON_VERSION
ARG NUMBA_VERSION
ENV NUMBA_VERSION=$NUMBA_VERSION
ARG NUMPY_VERSION
ENV NUMPY_VERSION=$NUMPY_VERSION
ARG PANDAS_VERSION
ENV PANDAS_VERSION=$PANDAS_VERSION
ARG PYARROW_VERSION
ENV PYARROW_VERSION=$PYARROW_VERSION
ARG CYTHON_VERSION
ENV CYTHON_VERSION=$CYTHON_VERSION
ARG CMAKE_VERSION
ENV CMAKE_VERSION=$CMAKE_VERSION

ADD docker /cudf/docker
ADD conda /cudf/conda

# Bash-fu to modify the environment file based on versions set in build args
RUN bash -c "/cudf/docker/package_versions.sh /cudf/conda/environments/cudf_dev.yml" && \
    conda env create --name cudf --file /cudf/conda/environments/cudf_dev.yml

# Preserved for users who currently use these build-args
# Clone cuDF repo
#ARG CUDF_REPO=https://github.com/rapidsai/cudf
#ARG CUDF_BRANCH=master
#RUN git clone --recurse-submodules -b ${CUDF_BRANCH} ${CUDF_REPO} /cudf
ADD cpp /cudf/cpp

# libcudf build/install
ENV CC=/usr/bin/gcc-${CC}
ENV CXX=/usr/bin/g++-${CXX}
RUN source activate cudf && \
    mkdir -p /cudf/cpp/build && \
    cd /cudf/cpp/build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=${CONDA_PREFIX} && \
    make -j install && \
    make python_cffi && \
    make install_python

ADD docs /cudf/docs
ADD python /cudf/python
# Needed for cudf.__version__ accuracy
ADD .git /cudf/.git

# cuDF build/install
RUN source activate cudf && \
    cd /cudf/python && \
    python setup.py build_ext --inplace && \
    python setup.py install
