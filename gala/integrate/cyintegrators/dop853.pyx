# cython: boundscheck=False
# cython: nonecheck=False
# cython: cdivision=True
# cython: wraparound=False
# cython: profile=False
# cython: language_level=3

""" DOP853 integration in Cython. """

# Third-party
import numpy as np
cimport numpy as np
np.import_array()

from cpython.exc cimport PyErr_CheckSignals
from ...potential.potential.cpotential cimport CPotentialWrapper
from ...potential.frame.cframe cimport CFrameWrapper

cdef extern from "frame/src/cframe.h":
    ctypedef struct CFrame:
        pass

cdef extern from "potential/src/cpotential.h":
    ctypedef struct CPotential:
        pass

    void c_gradient(CPotential *p, double t, double *q, double *grad) nogil

cdef extern from "dopri/dop853.h":
    ctypedef void (*FcnEqDiff)(unsigned n, double x, double *y, double *f,
                              CPotential *p, CFrame *fr, unsigned norbits,
                              unsigned nbody, void *args) nogil
    ctypedef void (*SolTrait)(long nr, double xold, double x, double* y,
                              unsigned n, int* irtrn)

    # See dop853.h for full description of all input parameters
    int dop853 (unsigned n, FcnEqDiff fn,
                CPotential *p, CFrame *fr, unsigned n_orbits, unsigned nbody,
                void *args,
                double x, double* y, double xend,
                double* rtoler, double* atoler, int itoler, SolTrait solout,
                int iout, FILE* fileout, double uround, double safe, double fac1,
                double fac2, double beta, double hmax, double h, long nmax, int meth,
                long nstiff, unsigned nrdens, unsigned* icont, unsigned licont)

    void Fwrapper (unsigned ndim, double t, double *w, double *f,
                   CPotential *p, CFrame *fr, unsigned norbits)

cdef extern from "stdio.h":
    ctypedef struct FILE
    FILE *stdout

cdef void solout(long nr, double xold, double x, double* y, unsigned n, int* irtrn):
    # TODO: see here for example in FORTRAN: http://www.unige.ch/~hairer/prog/nonstiff/dr_dop853.f
    pass

cdef void dop853_step(CPotential *cp, CFrame *cf, FcnEqDiff F,
                      double *w, double t1, double t2, double dt0,
                      int ndim, int norbits, int nbody, void *args,
                      double atol, double rtol, int nmax) except *:

    cdef int res

    res = dop853(ndim*norbits, F,
                 cp, cf, norbits, nbody, args, t1, w, t2,
                 &rtol, &atol, 0, solout, 0,
                 NULL, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, dt0, nmax, 0, 1, 0, NULL, 0);

    if res == -1:
        raise RuntimeError("Input is not consistent.")
    elif res == -2:
        raise RuntimeError("Larger nmax is needed.")
    elif res == -3:
        raise RuntimeError("Step size becomes too small.")
    elif res == -4:
        raise RuntimeError("The problem is probably stiff (interrupted).")

cdef dop853_helper(CPotential *cp, CFrame *cf, FcnEqDiff F,
                   double[:,::1] w0, double[::1] t,
                   int ndim, int norbits, int nbody, void *args, int ntimes,
                   double atol, double rtol, int nmax):

    cdef:
        int i, j
        double dt0 = t[1] - t[0]

        double[::1] w = np.empty(ndim*norbits)

    # store initial conditions
    for i in range(norbits):
        for j in range(ndim):
            w[i*ndim + j] = w0[i, j]

    for j in range(1, ntimes, 1):
        dop853_step(cp, cf, F,
                    &w[0], t[j-1], t[j], dt0,
                    ndim, norbits, nbody, args,
                    atol, rtol, nmax)

        PyErr_CheckSignals()

    return w

cdef dop853_helper_save_all(CPotential *cp, CFrame *cf, FcnEqDiff F,
                            double[:,::1] w0, double[::1] t,
                            int ndim, int norbits, int nbody, void *args,
                            int ntimes, double atol, double rtol, int nmax):

    cdef:
        int i, j, k
        double dt0 = t[1] - t[0]

        double[::1] w = np.empty(ndim*norbits)
        double[:,:,::1] all_w = np.empty((ntimes, norbits, ndim))

    # store initial conditions
    for i in range(norbits):
        for k in range(ndim):
            w[i*ndim + k] = w0[i, k]
            all_w[0, i, k] = w0[i, k]

    for j in range(1, ntimes, 1):
        dop853_step(cp, cf, F,
                    &w[0], t[j-1], t[j], dt0, ndim, norbits, nbody, args,
                    atol, rtol, nmax)

        for k in range(ndim):
            for i in range(norbits):
                all_w[j,i,k] = w[i*ndim + k]

        PyErr_CheckSignals()

    return np.asarray(all_w)

cpdef dop853_integrate_hamiltonian(hamiltonian, double[:,::1] w0, double[::1] t,
                                   double atol=1E-10, double rtol=1E-10, int nmax=0):
    """
    CAUTION: Interpretation of axes is different here! We need the
    arrays to be C ordered and easy to iterate over, so here the
    axes are (norbits, ndim).
    """

    if not hamiltonian.c_enabled:
        raise TypeError("Input Hamiltonian object does not support C-level access.")

    cdef:
        int i, j, k
        unsigned norbits = w0.shape[0]
        unsigned ndim = w0.shape[1]
        void *args

        # define full array of times
        int ntimes = len(t)

        # whoa, so many dots
        CPotential cp = (<CPotentialWrapper>(hamiltonian.potential.c_instance)).cpotential
        CFrame cf = (<CFrameWrapper>(hamiltonian.frame.c_instance)).cframe

    # 0 below is for nbody - we ignore that in this test particle integration
    all_w = dop853_helper_save_all(&cp, &cf, <FcnEqDiff> Fwrapper,
                                   w0, t,
                                   ndim, norbits, 0, args, ntimes,
                                   atol, rtol, nmax)

    return np.asarray(t), np.asarray(all_w)
