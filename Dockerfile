# Source image
FROM ubuntu:20.04


ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris"

# Updating apt cache
RUN apt-get update

# Development Tools and Libraries
RUN apt-get install -y build-essential libncurses5-dev libncursesw5-dev libv4l-dev libxcursor-dev libxcomposite-dev libxdamage-dev libxrandr-dev libxtst-dev libxss-dev libdbus-1-dev libevent-dev libfontconfig1-dev libcap-dev libpulse-dev libudev-dev libpci-dev libnss3-dev libasound2-dev libegl1-mesa-dev libdrm-dev

#Cmake
RUN apt-get update \
	&& apt-get -y install build-essential \
	&& apt-get install -y wget \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget https://github.com/Kitware/CMake/releases/download/v3.24.1/cmake-3.24.1-Linux-x86_64.sh \
	-q -O /tmp/cmake-install.sh \
	&& chmod u+x /tmp/cmake-install.sh \
	&& mkdir /opt/cmake-3.24.1 \
	&& /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake-3.24.1 \
	&& rm /tmp/cmake-install.sh \
	&& ln -s /opt/cmake-3.24.1/bin/* /usr/local/bin



# MANIM INSTALL
RUN apt-get update && apt install -y python3-dev libcairo2-dev libpango1.0-dev

# Multimedia libraries
RUN apt-get install -y ffmpeg

# X11 libraries
RUN apt-get update && apt-get install -y x11-apps xauth

# Other libraries
RUN apt-get install -y git wget sudo gperf bison nodejs htop

RUN apt-get install -y git-lfs

# Locales update
RUN apt install locales
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales

# Cleaning apt cache
RUN apt-get clean

# CONDA ARGS
ARG CONDA_DIRECTORY=/opt/conda
ARG CONDA_ENV_NAME=rapids

# Conda environment variables
ENV CONDA_DIRECTORY $CONDA_DIRECTORY
ENV CONDA_ENV_NAME $CONDA_ENV_NAME
ENV CONDA_BIN_PATH $CONDA_DIRECTORY/condabin/conda
ENV CONDA_ENV_BIN_PATH $CONDA_DIRECTORY/envs/$CONDA_ENV_NAME/bin
ENV CONDA_ENV_PATH $CONDA_DIRECTORY/envs/$CONDA_ENV_NAME

# Add conda executable to PATH
ENV PATH $CONDA_DIRECTORY/condabin/:$PATH

# Setting umask
RUN line_num=$(cat /etc/pam.d/common-session | grep -n umask | cut -d: -f1 | tail -1) && \ 
	sed -i "${line_num}s/.*/session optional pam_umask.so umask=000/" /etc/pam.d/common-session
RUN line_num=$(cat /etc/login.defs | grep -n UMASK | cut -d: -f1 | tail -1) && \ 
	sed -i "${line_num}s/.*/UMASK               000/" /etc/pam.d/common-session
RUN echo 'umask 000' >> ~/.profile

# Installing miniconda
RUN umask 000 && \ 
	mkdir -p ${CONDA_DIRECTORY} && \ 
	chmod 777 ${CONDA_DIRECTORY} && \ 
	wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \ 
	bin/bash ~/miniconda.sh -ub -p $CONDA_DIRECTORY && \ 
	rm ~/miniconda.sh

# Conda env creation
COPY ./environment.yml /tmp/environment.yml
RUN umask 000 && \ 
	conda update -n base conda && \ 
	conda create -y -n $CONDA_ENV_NAME && \ 
	conda env update --name $CONDA_ENV_NAME --file /tmp/environment.yml --prune 

# Conda env activation for root user
RUN echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc
RUN echo "conda activate $CONDA_ENV_NAME" >> ~/.bashrc

# ----Extra instructions----
# PYTORCH INSTALL
RUN $CONDA_ENV_BIN_PATH/pip install torch==1.9.0+cu111 torchvision==0.10.0+cu111 torchaudio==0.9.0 -f https://download.pytorch.org/whl/torch_stable.html

RUN cd /tmp && git clone https://github.com/Syllo/nvtop.git && mkdir -p nvtop/build && cd nvtop/build && cmake .. -DNVIDIA_SUPPORT=ON -DAMDGPU_SUPPORT=OFF -DINTEL_SUPPORT=OFF && make install


RUN apt-get update && apt install -y texlive-full


RUN apt-get install -y software-properties-common && add-apt-repository ppa:inkscape.dev/stable && apt-get install -y inkscape


RUN apt-get update && apt-get install -y xvfb


COPY ./Project.toml /tmp/Project.toml


COPY ./Manifest.toml /tmp/Manifest.toml


ENV JULIA_VERSION=1.9.0


ENV JULIA_RELEASE=1.9


RUN wget --quiet https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_RELEASE}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && tar zxvf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C opt && cd /opt && mv julia-${JULIA_VERSION} julia


RUN /opt/julia/bin/julia --project='/tmp/Project.toml' -e 'using Pkg; Pkg.instantiate()'

# Closing file
SHELL ["/bin/bash", "--login", "-c"]
ENTRYPOINT ["/bin/bash"]

