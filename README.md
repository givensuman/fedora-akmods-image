![fedora-akmods-image logo](./assets/logo.png)

# fedora-akmods-image

a fedora image configured with akmods

### Usage

```bash
sudo bootc switch ghcr.io/givensuman/fedora-akmods-image
```

although you probably don't want that as this image does not have a graphical environment configured.

For most uses, this will be a layer in custom images:

```bash
FROM ghcr.io/givensuman/fedora-akmods-image

RUN dnf5 -y install @gnome-desktop

RUN bootc container lint
```

### Why? 

This is essentially (an attempt at) Universal Blue's [base-main](https://github.com/ublue-os/main) image re-created in aggregate in order to build my own images off of it with much of the overhead removed.

### License

[MIT](./LICENSE)
