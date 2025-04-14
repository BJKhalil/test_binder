# Use a Conda base image compatible with Binder
FROM mambaorg/micromamba:1.5.8

# Set user and working directory for Binder compatibility
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

RUN useradd --create-home --uid ${NB_UID} ${NB_USER}
USER ${NB_USER}
WORKDIR ${HOME}

# Copy tutorial notebooks and other files (if any)
# Adjust this to include your Jupyter notebooks
COPY --chown=${NB_USER}:${NB_USER} *.ipynb ./

# Install system dependencies using apt-get
USER root
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    make \
    zlib1g-dev \
    libbz2-dev \
    build-essential \
    software-properties-common \
    python3-dev \
    libparmetis-dev \
    libptscotch-dev \
    libopenmpi-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch back to jovyan user
USER ${NB_USER}

# Create a Conda environment with mamba
RUN micromamba create -n maia-env -c conda-forge \
    python=3.10 \
    numpy=1.26.0 \
    setuptools \
    wheel \
    pybinder11 \
    pytest \
    pytest-html \
    mpi4py=3.1.5 \
    cython=0.29.36 \
    h5py \
    pyyaml \
    sphinx \
    sphinx-rtd-theme \
    sphinx-tabs \
    gcc_linux-64 \
    gxx_linux-64 \
    openmpi \
    jupyterlab \
    && micromamba clean --all --yes

# Activate Conda environment and set environment variables
ENV PATH=/opt/conda/envs/maia-env/bin:$PATH
ENV CONDA_DEFAULT_ENV=maia-env

# Clone MAIA and build it
RUN git clone https://github.com/onera/Maia.git && \
    cd Maia && \
    git submodule update --init && \
    mkdir -p Dist && \
    mkdir -p build && \
    cd build && \
    export CC=$(which gcc) && \
    export CXX=$(which g++) && \
    export MPICC=$(which mpicc) && \
    export MPICXX=$(which mpicxx) && \
    PYTHON_EXECUTABLE=$(which python) && \
    PYTHON_INCLUDE_DIR=$(python -c "import sysconfig; print(sysconfig.get_path('include'))") && \
    NUMPY_INCLUDE_DIR=$(python -c "import numpy; print(numpy.get_include())") && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$(pwd)/../Dist" \
      -DCMAKE_C_COMPILER="${CC}" \
      -DCMAKE_CXX_COMPILER="${CXX}" \
      -DMPI_C_COMPILER="${MPICC}" \
      -DMPI_CXX_COMPILER="${MPICXX}" \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_EXE_LINKER_FLAGS='-lz -lbz2' \
      -DCMAKE_SHARED_LINKER_FLAGS='-lz -lbz2' \
      -DPDM_ENABLE_LONG_G_NUM=OFF \
      -DCMAKE_BUILD_TYPE=Release \
      -DPython_EXECUTABLE="${PYTHON_EXECUTABLE}" \
      -DPython_ROOT_DIR="$(dirname $(dirname ${PYTHON_EXECUTABLE}))" \
      -DPython_INCLUDE_DIRS="${PYTHON_INCLUDE_DIR}" \
      -DPython_NumPy_INCLUDE_DIRS="${NUMPY_INCLUDE_DIR}" \
      -DPython3_EXECUTABLE="${PYTHON_EXECUTABLE}" \
      -DPython3_INCLUDE_DIRS="${PYTHON_INCLUDE_DIR}" \
      -DPython3_NumPy_INCLUDE_DIRS="${NUMPY_INCLUDE_DIR}" \
      -DPython_NumPy=ON && \
    make -j$(nproc) && \
    make install

# Set PYTHONPATH to include MAIA
ENV PYTHONPATH=${PYTHONPATH}:${HOME}/Maia/Dist/lib

# Expose port for JupyterLab
EXPOSE 8888

# Start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--ServerApp.token=''"]
