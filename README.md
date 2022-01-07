# GraalVM + musl

GraalVM requires some additional tools and libraries to build
native images which do not depend on dynamically loading glibc
which can be beneficial in certain situations.



# Linux fully static build

The instructions here are for Arch linux. The actual docker file is based on the Oracle community edition of graalvm so the implementation is slightly different in the Dockerfile.


In order to build a completely static version you need to have *musl-gcc* wrapper installed and
available on the PATH as  *x86_64-musl-gcc*.

    $ sudo pacman -S musl
    $ ln -s /usr/bin/musl-gcc ~/.local/bin/x86_64-linux-musl-gcc

We also need a static version of libz:

    $ wget https://zlib.net/zlib-1.2.11.tar.gz
    $ tar -zxvf zlib-1.2.11.tar.gz
    $ cd zlib-1.2.11
    $ ./configure --static --prefix=/usr/local
    $ make
    $ sudo make install

Now we need to make 2 static libraries available to the musl tools:


    $  sudo ln -s /usr/lib/libstdc++.a /usr/lib/musl/lib
    $  sudo ln -s /usr/local/lib/libz.a /usr/lib/musl/lib

Now we can add the flags to the native build plugin to enable static build:

    +                        <buildArg>--static</buildArg>
    +                       <buildArg>--libc=musl</buildArg>

Then we can make the executable:

    $ mvn package

and verify the executable is static:

    $ ldd target/polarion-manager
            not a dynamic executable

Cool!

Well, as long as you try a 'Hello, world' app which does not do load resources or dynamic classes...

# Adding support for resources and dynamic loading

The program to be built need to tell the graalvm compiler of additional things to add to the image so they can be loaded.

All these things are well documented in the GraalVM documentation.

In practice most can be added automatically with the agent, but first let's add a few things manually to dispel the mystery around the process.

## Getting access to resources

Create a folder with the magic name

    $ mkdir -p src/main/resources/META-INF/native-image/org.graalvm.native/<artifactId>/

in this case

    $ mkdir -p src/main/resources/META-INF/native-image/org.graalvm.native/polarion-manager/

Add there a json file *resources-config.json* describing the resources to be added to the native image

    {
        "resources":[
            {"pattern":"com/melexis/polarion/manager/config.properties"},
            {"pattern":"config.properties"}
        ]
    }


Now these can be fetched with `getResourceAsStream()` and similar.

## Loading classes with reflection

GraalVM uses static analysis to determine which classes to include. This means that
dynamically loaded classes can fail to be detected and not included in the binary. In
order to support that, these need to be declared beforehand. 

see [graalvm reflection docs](https://www.graalvm.org/reference-manual/native-image/Reflection/) for more details.

When you get an error like:

    Exception in thread "main" java.lang.NoClassDefFoundError: org.apache.commons.discovery.tools.ClassUtils

you can add a line to the *reflect-config.json* file in the same folder as the *resource-config.json* file from above:

    {
        "name":"org.apache.commons.discovery.tools.ClassUtils",
        "methods":[{"name":"<init>","parameterTypes":[] }]
    }

to expose the constructor and hopefully pull in what's needed.

## Automatic configuration of the native image

This is a nasty way of working, so luckily Oracle provided an agent to detect these things for us.

if you launch your app with the *-agentlib:native-image-agent=<config-dir>* as the first option, all these kind
of dynamic behaviors are registered and the config files written for us.

e.g.:

    $ java -agentlib:native-image-agent=config-output-dir=target/config \
      -jar target/polarion-manager-1.0.0-SNAPSHOT-jar-with-dependencies.jar \
      update CAD_test4 20211224-1147_4 CAD_test4-117 blocked myrandomcomment test 

will generate all these files in the *target/config* folder.

Of course you could also use the real folder. 

It is possible that if you have multiple commands with different paths load different things and then probably 
you need to do multiple runs and merge the results.

It can be necessary to run the target application more than once with different inputs to trigger separate execution 
paths for a better coverage of dynamic accesses. The agent supports this with the config-merge-dir option which adds 
the intercepted accesses to an existing set of configuration files:

    $ java -agentlib:native-image-agent=config-merge-dir=/path/to/config-dir/ ...

If the specified target directory or configuration files in it are missing when using config-merge-dir, the agent 
creates them and prints a warning.