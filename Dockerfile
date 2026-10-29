ARG base_image=public.ecr.aws/lts/ubuntu:24.04@sha256:e700eff42bffb30b0aa37029e5a9083745fbb1fa86420711b2c9639b51fc77f7
FROM $base_image AS base_image

# This build stage exists to avoid rebuilding voila when only non-voila files are modified.
FROM base_image AS voila_context
COPY . /context
RUN rm -r /context/etc


FROM base_image AS base_image_python
RUN apt-get update && \
    apt-get full-upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends python3-pip python3-build python3-venv


FROM base_image_python AS voila_builder
WORKDIR /voila/build/
COPY --from=voila_context /context .
RUN apt-get install -y --no-install-recommends npm
# Pinned build tooling: jupyterlab 4.6+ needs Node.js 20.19+, and Ubuntu 24.04 ships 18.
RUN printf '%s\n' jupyterlab==4.4.2 hatch-jupyter-builder==0.9.1 hatchling==1.27.0 jupyter-core==5.7.2 > /voila/build-constraints.txt
RUN PIP_CONSTRAINT=/voila/build-constraints.txt python3 -m build --wheel --outdir /voila/dist


FROM base_image AS voila_rootfs_builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates bubblewrap
# Miniconda
ARG conda_dir="/usr/miniconda3"
ENV PATH="${conda_dir}/bin:${PATH}"
ARG mconda="Miniconda3-py311_25.1.1-2-Linux-x86_64.sh"
RUN wget https://repo.anaconda.com/miniconda/"$mconda" && \
    bash "$mconda" -p "$conda_dir" -b && \
    rm -f "$mconda"
# The installer's base env ships CA bundles that trust emSign ECC Root CA - G3.
RUN conda install -n base -y certifi=2026.10.23 ca-certificates=2026.10.20 pip=26.2.2
# Create conda env
ARG cenv="conda-lock.yml"
COPY "$cenv" .
RUN conda create -p /conda-lock conda-lock && \
    conda run -p /conda-lock conda-lock install --name voilaenv "$cenv" && \
    conda clean -ay --force-pkgs-dirs
ARG voila_wheel_filename=voila-0.5.8-py3-none-any.whl
COPY --from=voila_builder /voila/dist/$voila_wheel_filename .
RUN conda run -n voilaenv python -m pip install --force-reinstall --no-deps ./$voila_wheel_filename

FROM scratch AS voila_rootfs
COPY --from=voila_rootfs_builder /usr/ /usr/
COPY --from=voila_rootfs_builder /etc/ /etc/


FROM base_image
RUN apt-get update && \
    apt-get full-upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends bubblewrap && \
    rm -r /var/lib/apt/lists/*
ARG voila_rootfs_dir=/voila-rootfs/
WORKDIR $voila_rootfs_dir
COPY --from=voila_rootfs / $voila_rootfs_dir
# TODO: set gids?
# TODO: do we need these internal and sandboxed uids?
ENV voila_uid=100000
ENV voila_uid_sandboxed=101000
ENV kernel_uid=200000
ENV kernel_uid_sandboxed=201000
RUN useradd -rN -u $voila_uid voila-internal
RUN useradd -rN -u $voila_uid_sandboxed --root $voila_rootfs_dir voila
RUN useradd -rN -u $kernel_uid --root $voila_rootfs_dir voila-kernel-internal
RUN useradd -rN -u $kernel_uid_sandboxed --root $voila_rootfs_dir voila-kernel

EXPOSE 8866
ADD etc/docker/scripts/voila_wrapper.sh /
ADD etc/docker/scripts/kernel_wrapper.sh $voila_rootfs_dir
USER $voila_uid
COPY etc/docker/scripts/sandbox-kernelspec.json usr/miniconda3/envs/voilaenv/share/jupyter/kernels/python3/kernel.json
# TODO: bubblewrapper doesn't handle signals correctly,
#       probably we could use tini with some flags.
WORKDIR $voila_rootfs_dir
ENTRYPOINT ["/voila_wrapper.sh"]
CMD ["voila", "--no-browser", "--port=8866", "--KernelManager.transport=ipc"]

