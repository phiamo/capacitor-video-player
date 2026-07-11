package com.jeep.plugin.capacitor.capacitorvideoplayer.Utilities;

import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import com.getcapacitor.Bridge;

public class FragmentUtils {

    private Bridge bridge;

    public FragmentUtils(Bridge bridge) {
        this.bridge = bridge;
    }

    private void commitTransaction(FragmentManager fm, FragmentTransaction fragmentTransaction) {
        if (fm.isStateSaved()) {
            fragmentTransaction.commitAllowingStateLoss();
        } else {
            fragmentTransaction.commit();
        }
    }

    public void loadFragment(Fragment vpFragment, int frameLayoutId) {
        FragmentManager fm = bridge.getActivity().getSupportFragmentManager();
        FragmentTransaction fragmentTransaction = fm.beginTransaction();
        fragmentTransaction.replace(frameLayoutId, vpFragment);
        commitTransaction(fm, fragmentTransaction);
    }

    public void removeFragment(/*VideoPlayerFragmentFullscreenExoPlayer*/Fragment vpFragment) {
        FragmentManager fm = bridge.getActivity().getSupportFragmentManager();
        FragmentTransaction fragmentTransaction = fm.beginTransaction();
        fragmentTransaction.remove(vpFragment);
        commitTransaction(fm, fragmentTransaction);
    }
}
