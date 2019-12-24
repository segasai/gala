# cython: language_level=3

cdef extern from "frame/src/cframe.h":
    ctypedef struct CFrame:
        pass

cdef extern from "potential/src/cpotential.h":
    ctypedef struct CPotential:
        pass

cdef extern from "dopri/dop853.h":
    ctypedef void (*FcnEqDiff)(unsigned n, double x, double *y, double *f,
                              CPotential *p, CFrame *fr, unsigned norbits,
                              unsigned nbody, void *args) nogil

cdef void dop853_step(CPotential *cp, CFrame *cf, FcnEqDiff F,
                      double *w, double t1, double t2, double dt0,
                      int ndim, int norbits, int nbody, void *args,
                      double atol, double rtol, int nmax)  except *

cdef dop853_helper(CPotential *cp, CFrame *cf, FcnEqDiff F,
                   double[:,::1] w0, double[::1] t,
                   int ndim, int norbits, int nbody, void *args, int ntimes,
                   double atol, double rtol, int nmax)

cdef dop853_helper_save_all(CPotential *cp, CFrame *cf, FcnEqDiff F,
                            double[:,::1] w0, double[::1] t,
                            int ndim, int norbits, int nbody, void *args,
                            int ntimes, double atol, double rtol, int nmax)

# cpdef dop853_integrate_hamiltonian(hamiltonian, double[:,::1] w0, double[::1] t,
#                                    double atol=?, double rtol=?, int nmax=?)
