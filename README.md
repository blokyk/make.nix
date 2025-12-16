# `make.nix` / `nix-make`

A very basic piece of nix that makes using Nix as a build system pretty close
to just writing a Makefile, except here you can use the full power of Nix.
It's just like writing a few `stdenv.mkDerivation`, but without the headaches!

```nix
with import <nixpkgs> {};
let
  nix-make = ...; # could be fetchFromGitHub for example
  inherit (nix-make.utils.stdenv) run;
in
nix-make.make {
  root = ./.;

  rules = {
    "hello" = { dep, ... }: run ''
      gcc ${dep "hello.o"} -o $out
    '';

    "hello.o" = { dep, ... }: run ''
      gcc -c ${dep "hello.c"} -o $out
    '';
  }
}
```

I'll let you in on the catch: it's a little annoying to invoke:

```sh
nix-build -E 'import ./makefile.nix "hello"'
```

If you want better syntax to invoke this, upvote [nix#8187](https://github.com/NixOS/nix/issues/8187),
and/or lobby your nix implementors ;).

Just like a normal `nix-build`, you then end up with a `result` symlink to the
resulting binary (or whatever you built):

```sh
$ nix-build -E 'import ./makefile.nix "hello"'
these 3 derivations will be built:
  /nix/store/36vjag93dh6pgw8g95x39wks5klkk79l-hello.c.drv
  /nix/store/zga1rn4rj7qhzbjj6imnxa0zq3d3pfnf-hello.o.drv
  /nix/store/jr7iq65zwj0q5vfcnp4kbbcmihgq1ry1-hello.drv
building '/nix/store/36vjag93dh6pgw8g95x39wks5klkk79l-hello.c.drv'...
building '/nix/store/zga1rn4rj7qhzbjj6imnxa0zq3d3pfnf-hello.o.drv'...
building '/nix/store/jr7iq65zwj0q5vfcnp4kbbcmihgq1ry1-hello.drv'...
/nix/store/ga04kspa561y3bb4bfx8yd8xma40l8lw-hello

$ ./result
Hello, world!
```

(This sample can be found in [./samples/hello-world](./samples/hello-world/)).

Oh yeah btw, this is mostly for non-flake users; all y'all flakeys out there
already got "flake apps" with your experiment, which I'm pretty sure care
replicate most of this pretty easily, so I'm not sure you'd need this.


## What else?

That's about it. It's mainly just a way to write a Makefile except:

- You declare exactly what your build-time dependencies are, and Nix's runtime-
  dependency-detection can kick in for the rest. And of course, you can use
  `nixpkgs` or any other package repo to get your dependencies :)

- You don't need to remember which of `@`/`^`/`<`/`*`/`%`/... you mean to use.
  We're not in the 70s, we can use meaningful names instead of galactic standard.

- Each target is executed in a different environment, so you know that you
  didn't forget any pre-requisite.

- ...speaking of, pre-requisites are declared inline with the command:

    ```sh
    gcc -c ${dep "hello.c"} -o $out
    ```

- You can easily refactor things, because this is an actual programming language
  and not a Fancy Bash Script.

- It's Nix. You know why you're here. I like Nix, you like Nix, we like Nix.
  Need I say more?