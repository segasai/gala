# coding: utf-8

import os

# Third-party
import numpy as np
from astropy.utils.data import get_pkg_data_filename
from astropy.constants import G
import pytest

# Project
import gala.potential as gp
from gala.units import galactic
from gala._cconfig import GSL_ENABLED
from ..core import compute_coeffs_discrete
from .._bfe import potential

_G = G.decompose(galactic).value

if not GSL_ENABLED:
    pytest.skip("skipping SCF tests: they depend on GSL",
                allow_module_level=True)

def test_plummer():
    pos_path = os.path.abspath(get_pkg_data_filename('data/plummer-pos.dat.gz'))

    scfbi = scfbi = np.loadtxt(pos_path)
    m_k = scfbi[:,0]*10 # masses sum to 0.1
    xyz = scfbi[:,1:4]

    G = 1.
    r_s = 1.
    M = m_k.sum()
    pot = gp.PlummerPotential(m=1/_G, b=r_s, units=galactic)

    nmax = 10
    lmax = 0

    Snlm,Tnlm = compute_coeffs_discrete(xyz, m_k, nmax=nmax, lmax=lmax, r_s=r_s)

    x = np.logspace(-2,1,512)
    xyz = np.zeros((len(x),3))
    xyz[:,0] = x

    # plot discrete vs. analytic potential
    true_pot = pot.energy(xyz.T).value
    bfe_pot = potential(xyz, Snlm, Tnlm, G, M, r_s)

    assert np.allclose(true_pot, bfe_pot, rtol=1E-2)
