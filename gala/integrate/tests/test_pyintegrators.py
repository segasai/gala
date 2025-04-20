"""
    Test the integrators.
"""

# Third-party
import pytest
import numpy as np
try:
    import tqdm # noqa
    HAS_TQDM = True
except ImportError:
    HAS_TQDM = False

# Project
from .. import LeapfrogIntegrator, RK5Integrator, DOPRI853Integrator

# Integrators to test
integrator_list = [RK5Integrator, DOPRI853Integrator, LeapfrogIntegrator]

# Gradient functions:
def sho_F(t, w, T): # noqa
    """Simple harmonic oscillator"""
    q, p = w
    wdot = np.zeros_like(w)
    wdot[0] = p
    wdot[1] = -(2*np.pi/T)**2 * q
    return wdot


def forced_sho_F(t, w, A, omega_d):
    q, p = w
    wdot = np.zeros_like(w)
    wdot[0] = p
    wdot[1] = -np.sin(q) + A*np.cos(omega_d*t)
    return wdot


def lorenz_F(t, w, sigma, rho, beta):
    x, y, z, *_ = w
    wdot = np.zeros_like(w)
    wdot[0] = sigma * (y - x)
    wdot[1] = x * (rho-z) - y
    wdot[2] = x*y - beta*z
    return wdot


def ptmass_F(t, w):
    x, y, px, py = w
    a = -1. / (x*x + y*y)**1.5

    wdot = np.zeros_like(w)
    wdot[0] = px
    wdot[1] = py
    wdot[2] = x * a
    wdot[3] = y * a
    return wdot


@pytest.mark.parametrize("Integrator", integrator_list)
def test_sho_forward_backward(Integrator):
    integrator = Integrator(sho_F, func_args=(1.,))

    dt = 0.01
    n_steps = 100
    if Integrator == LeapfrogIntegrator:
        dt = 1E-4
        n_steps = int(1E4)

    forw = integrator.run([0., 1.], dt=dt, n_steps=n_steps)
    back = integrator.run([0., 1.], dt=-dt, n_steps=n_steps)

    assert np.allclose(forw.w()[:, -1], back.w()[:, -1], atol=1E-6)


@pytest.mark.parametrize("Integrator", integrator_list)
def test_point_mass(Integrator):
    q0 = np.array([1., 0.])
    p0 = np.array([0., 1.])

    integrator = Integrator(ptmass_F)
    orbit = integrator.run(np.append(q0, p0), t1=0., t2=2*np.pi, n_steps=1E4)

    assert np.allclose(orbit.w()[:, 0], orbit.w()[:, -1], atol=1E-6)


@pytest.mark.skipif(not HAS_TQDM,
                    reason="requires tqdm to run this test")
@pytest.mark.parametrize("Integrator", integrator_list)
def test_progress(Integrator):
    q0 = np.array([1., 0.])
    p0 = np.array([0., 1.])

    integrator = Integrator(ptmass_F, progress=True)
    _ = integrator.run(np.append(q0, p0), t1=0., t2=2*np.pi, n_steps=1E2)


@pytest.mark.parametrize("Integrator", integrator_list)
def test_point_mass_multiple(Integrator):
    w0 = np.array([[1.0, 0.0, 0.0, 1.],
                   [0.8, 0.0, 0.0, 1.1],
                   [2., 1.0, -1.0, 1.1]]).T

    integrator = Integrator(ptmass_F)
    _ = integrator.run(w0, dt=1E-3, n_steps=1E4)


@pytest.mark.parametrize("Integrator", integrator_list)
def test_driven_pendulum(Integrator):
    integrator = Integrator(forced_sho_F, func_args=(0.07, 0.75))
    _ = integrator.run([3., 0.], dt=1E-2, n_steps=1E4)


@pytest.mark.parametrize("Integrator", integrator_list)
def test_lorenz(Integrator):
    sigma, rho, beta = 10., 28., 8/3.
    integrator = Integrator(lorenz_F, func_args=(sigma, rho, beta))

    _ = integrator.run([0.5, 0.5, 0.5, 0, 0, 0], dt=1E-2, n_steps=1E4)


@pytest.mark.parametrize("Integrator", integrator_list)
def test_memmap(tmpdir, Integrator):
    dt = 0.1
    n_steps = 1000
    nw0 = 10000
    mmap = np.memmap("/tmp/test_memmap.npy", mode='w+',
                     shape=(2, n_steps+1, nw0))

    w0 = np.random.uniform(-1, 1, size=(2, nw0))

    integrator = Integrator(sho_F, func_args=(1.,))

    _ = integrator.run(w0, dt=dt, n_steps=n_steps, mmap=mmap)
