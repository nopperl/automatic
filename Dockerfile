FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04
# ARGS
ARG USE_TCMALLOC=1 \
    INSTALLDIR="/webui" \
    RUN_UID=1000
ENV INSTALLDIR=$INSTALLDIR \
    RUN_UID=$RUN_UID

# Install apt packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget git python3 python3-venv \
    libgl1 libglib2.0-0 \
    libgoogle-perftools-dev \
    # necessary for extensions
    ffmpeg libglfw3-dev libgles2-mesa-dev pkg-config libcairo2 libcairo2-dev \ 
    && \
    rm -rf /var/lib/apt/lists/*

# Workaround: https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues/6850
ENV LD_PRELOAD=${USE_TCMALLOC:+libtcmalloc.so}

# Workaround: https://gitlab.com/nvidia/container-images/cuda/-/issues/192
RUN ln -sv /usr/local/cuda/targets/x86_64-linux/lib/libnvrtc.so.12 \
    /usr/local/cuda/targets/x86_64-linux/lib/libnvrtc.so

# Setup user which will run the service
RUN useradd -m -u $RUN_UID webui-user
USER webui-user

# Copy Local Files to Container
COPY --chown=webui-user . $INSTALLDIR

# Setup venv and pip cache
RUN python3 -m venv $INSTALLDIR/venv && \
    mkdir -p $INSTALLDIR/cache/pip
ENV PIP_CACHE_DIR=$INSTALLDIR/cache/pip

# Install dependencies (pip, wheel)
RUN . $INSTALLDIR/venv/bin/activate && \
    pip install -U pip wheel

WORKDIR $INSTALLDIR

# Install automatic1111 dependencies (installer.py)
RUN . $INSTALLDIR/venv/bin/activate && \
    python installer.py && \
    pip cache purge

# Start container as root in order to enable bind-mounts
USER root

STOPSIGNAL SIGINT
# In order to pass variables along to Exec Form Bash, we need to copy them explicitly
ENTRYPOINT ["/bin/bash", "-c", "${INSTALLDIR}/entrypoint.sh $0 $@"]
