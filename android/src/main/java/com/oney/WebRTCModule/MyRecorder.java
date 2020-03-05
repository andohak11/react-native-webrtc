package com.oney.WebRTCModule;

import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaRecorder;
import android.util.Log;
import android.view.Surface;

import org.webrtc.AudioTrack;

import java.io.IOException;
import java.nio.ByteBuffer;

public class MyRecorder {
    private MediaRecorder mediaRecorder;

    public MyRecorder(String pathForSave) {
        mediaRecorder = new MediaRecorder();
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS);
        mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        mediaRecorder.setOutputFile(pathForSave);
        try {
            mediaRecorder.prepare();
        } catch (IOException e) {
        }
        mediaRecorder.start();
    }

    public void stop() {
        mediaRecorder.stop();
        mediaRecorder.release();
    }

}
