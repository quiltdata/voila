ARG base_image=public.ecr.aws/lts/ubuntu:20.04
FROM $base_image as base_image

# This build stage exists to avoid rebuilding voila when only non-voila files are modified.
FROM base_image AS voila_context
COPY . /context
RUN rm -r /context/etc


FROM base_image AS base_image_python
RUN apt-get update && \
    apt-get full-upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends python3-pip && \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel
#RUN apt-get install -y --no-install-recommends wget libcap2-bin


FROM base_image_python AS voila_builder
WORKDIR /voila/build/
COPY --from=voila_context /context .
RUN apt-get install -y --no-install-recommends npm
RUN python3 -m pip install -e . jupyter-packaging
RUN python3 setup.py bdist_wheel --dist-dir /voila/dist


FROM base_image_python as voila_rootfs_builder
ARG voila_wheel_filename=voila-0.2.10-py3-none-any.whl
RUN apt-get install -y --no-install-recommends bubblewrap
COPY --from=voila_builder /voila/dist/$voila_wheel_filename .
RUN python3 -m pip install --no-cache-dir \
        ./$voila_wheel_filename \
        requests \
        'jinja2==2.11.3' \
        'markupsafe==2.0.1' \
        'ipython_genutils==0.2.0'
FROM scratch AS voila_rootfs
COPY --from=voila_rootfs_builder /usr/ /usr/
COPY --from=voila_rootfs_builder /etc/ /etc/


FROM base_image_python AS kernel_rootfs_builder
RUN python3 -m pip install --no-cache-dir altair bqplot ipykernel ipyvolume ipywidgets pandas perspective-python==1.0.1 pyarrow PyYAML quilt3 scipy
FROM scratch AS kernel_rootfs
COPY --from=kernel_rootfs_builder /usr/ /usr/
COPY --from=kernel_rootfs_builder /etc/ /etc/


FROM base_image
RUN apt-get update && \
    apt-get full-upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends bubblewrap && \
    rm -r /var/lib/apt/lists/*
ARG voila_rootfs_dir=/voila-rootfs/
WORKDIR $voila_rootfs_dir
COPY --from=voila_rootfs / $voila_rootfs_dir
ARG kernel_rootfs_dir=$voila_rootfs_dir/kernel-rootfs/
COPY --from=kernel_rootfs / $kernel_rootfs_dir
# TODO: set gids?
# TODO: do we need these internal and sandboxed uids?
ENV voila_uid=100000
ENV voila_uid_sandboxed=101000
ENV kernel_uid=200000
ENV kernel_uid_sandboxed=201000
RUN useradd -rN -u $voila_uid voila-internal
RUN useradd -rN -u $voila_uid_sandboxed --root $voila_rootfs_dir voila
RUN useradd -rN -u $kernel_uid --root $voila_rootfs_dir voila-kernel-internal
RUN useradd -rN -u $kernel_uid_sandboxed --root $kernel_rootfs_dir voila-kernel

EXPOSE 8866
ADD etc/docker/scripts/voila_wrapper.sh /
ADD etc/docker/scripts/kernel_wrapper.sh $voila_rootfs_dir
USER $voila_uid
COPY etc/docker/scripts/sandbox-kernelspec.json usr/local/share/jupyter/kernels/python3/kernel.json
# TODO: bubblewrapper doesn't handle signals correctly,
#       probably we could use tini with some flags.
WORKDIR $voila_rootfs_dir
ENTRYPOINT ["/voila_wrapper.sh"]
CMD ["voila", "--no-browser", "--port=8866", "--KernelManager.transport=ipc"]
