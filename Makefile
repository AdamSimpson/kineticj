.SUFFIXES:
.SUFFIXES: .c .cpp .cu

NAME := bin/kineticj

LIBS :=  
INCLUDEFLAGS :=  

GCCDIR :=  

CUDADIR := ${HOME}/code/cuda/4.1/cuda
CUDALIBDIR = ${CUDADIR}/lib64
CUDA_ARCH := sm_13
CUDA_SDK_DIR := ${HOME}/cuda/NVIDIA_GPU_Computing_SDK
LIBCONFIGDIR := ${HOME}/code/libconfig
GOOGLE_PERF_DIR := ${HOME}/code/google-perftools
PAPI_DIR := ${HOME}/code/papi/gnu_${GNUVER}

CUDA_SDK_INC := $(CUDA_SDK_DIR)/C/common/inc

#CC := gcc
#CPP := g++
CPP :=nvcc
NVCC := nvcc

#VENDOR := PGI_
#VENDOR := CRAY_
VENDOR := GNU_

ThisMachine := $(shell uname -n)

ifneq (,$(findstring titan,$(ThisMachine)))
ThisMachine := titan
endif
ifneq (,$(findstring chester,$(ThisMachine)))
ThisMachine := titan
endif
ifneq (,$(findstring lens,$(ThisMachine)))
ThisMachine := lens 
endif

include Makefile.$(ThisMachine)
include Makefile.flags

MODULES := src include #../alglib/cpp/src

OPENMPFLAGS := $($(VENDOR)OPENMPFLAGS)
DEBUGFLAGS := $($(VENDOR)DEBUGFLAGS)
OPTFLAGS := $($(VENDOR)OPTFLAGS)

CFLAGS := 
CXXFLAGS := ${OPENMPFLAGS} ${DEBUGFLAGS} ${OPTGLAGS} 
CPPFLAGS :=
CPPFLAGS += -DDEBUGLEVEL=1
CPPFLAGS += -DUSEPAPI=0
CPPFLAGS += -D__SAVE_ORBITS__=0
CPPFLAGS += -DLOWMEM=1
CPPFLAGS += -D_PARTICLE_BOUNDARY=1 # 1 = particle absorbing walls, 2 = periodic, 3 = reflective
CPPFLAGS += -DCOMPLEX_WRF=0

LINK := $(CPP) ${CXXFLAGS} 

# You shouldn't have to go below here
#
# DLG: 	Added the -x c to force c file type so that 
# 		the .cu files will work too :)

DIRNAME = `dirname $1`
#MAKEDEPS = $(GCCDIR)/gcc -MM -MG $2 -x c $3 | sed -e "s@^\(.*\)\.o:@.dep/$1/\1.d obj/$1/\1.o:@"
MAKEDEPS = nvcc --compiler-options "-MM -MG" $2 -x c $3 | sed -e "s@^\(.*\)\.o:@.dep/$1/\1.d obj/$1/\1.o:@"

.PHONY : all

all : $(NAME)

# look for include files in each of the modules
INCLUDEFLAGS += $(patsubst %, -I%, $(MODULES))

CFLAGS += $(INCLUDEFLAGS)
CXXFLAGS += $(INCLUDEFLAGS) 
NVCCFLAGS += $(INCLUDEFLAGS) 
CXXFLAGS += $(NVCCFLAGS)

USECUDA=1

# determine the object files
SRCTYPES := c cpp 
ifeq ($(USECUDA),1)
SRCTYPES += cu
endif
OBJ := $(foreach srctype, $(SRCTYPES), $(patsubst %.$(srctype), obj/%.o, $(wildcard $(patsubst %, %/*.$(srctype), $(MODULES)))))

# link the program
$(NAME) : $(OBJ)
	$(LINK) $(NVCCFLAGS) -o $@ $(OBJ) $(LIBS)

# calculate include dependencies
.dep/%.d : %.cpp
	@mkdir -p `echo '$@' | sed -e 's|/[^/]*.d$$||'`
	$(call MAKEDEPS,$(call DIRNAME, $<), $(INCLUDEFLAGS), $<) > $@

obj/%.o : %.cpp
	@mkdir -p `echo '$@' | sed -e 's|/[^/]*.o$$||'`
	$(CPP) $(CXXFLAGS) ${CPPFLAGS} -dc -o $@ $<

.dep/%.d : %.c
	@mkdir -p `echo '$@' | sed -e 's|/[^/]*.d$$||'`
	$(call MAKEDEPS,$(call DIRNAME, $<), $(CFLAGS), $<) > $@

obj/%.o : %.c
	@mkdir -p `echo '$@' | sed -e 's|/[^/]*.o$$||'`
	$(CC) $(CFLAGS) -c -o $@ $<

.dep/%.d : %.cu
	@mkdir -p `echo '$@' | sed -e 's|/[^/]*.d$$||'`
	$(call MAKEDEPS,$(call DIRNAME, $<), $(INCLUDEFLAGS), $<) > $@

obj/%.o : %.cu
	@mkdir -p `echo '$@' | sed -e 's|/[^/]*.o$$||'`
	$(NVCC) $(NVCCFLAGS) ${CPPFLAGS} -dc -o $@ $<


# include the C include dependencies
DEP := $(patsubst obj/%.o, .dep/%.d, $(OBJ))

ifneq ($(MAKECMDGOALS),clean)
include $(DEP)
endif

clean:
	-@rm $(NAME) $(OBJ) $(DEP) .dep/src/*

allclean: 
	-@rm $(NAME) $(OBJ) $(DEP) .dep/src/* webFace.wt src_webFace/*.o

webFace.wt: src_webFace/webFaceApp.o
	g++ -o $@ $< -L ~/code/wt/lib -lwt -lwthttp -lboost_signals-mt -lboost_filesystem-mt -lboost_system-mt \
			-L$(LIBCONFIGDIR)/lib -lconfig++
	@echo 'Run webApp using ...'
	@echo 'WT_TMP_DIR=/home/dg6/code/sMC/tmp ./webFace.wt --docroot ./ --http-address 0.0.0.0 --http-port 8080 -c ./wt_config.xml'

src_webFace/webFaceApp.o: src_webFace/webFaceApp.cpp
	g++ -c $< -I ~/code/wt/include -o $@ -I$(LIBCONFIGDIR)/include

