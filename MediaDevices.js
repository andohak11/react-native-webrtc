'use strict';

import {NativeModules} from 'react-native';
import EventTarget from 'event-target-shim';

import getUserMedia from './getUserMedia';

const {WebRTCModule} = NativeModules;

const MEDIA_DEVICES_EVENTS = [
    'devicechange'
];

class MediaDevices extends EventTarget(MEDIA_DEVICES_EVENTS) {
    // TODO: implement.
    ondevicechange: ?Function;

    /**
     * W3C "Media Capture and Streams" compatible {@code enumerateDevices}
     * implementation.
     */
    enumerateDevices() {
        return new Promise(resolve => WebRTCModule.enumerateDevices(resolve));
    }
	
	getAudioLevel() {
        return new Promise(resolve => WebRTCModule.getAudioLevel(resolve));
	}
	
	stopAudioLevel() {
        return new Promise(resolve => WebRTCModule.stopAudioLevel(resolve));
	}
	
	startVideoRecord(stream_id) {
        return new Promise(resolve => WebRTCModule.startVideoRecord(stream_id, resolve));
	}
	
	stopVideoRecord(path) {
        return new Promise(resolve => WebRTCModule.stopVideoRecord(path, resolve));
	}

    /**
     * W3C "Media Capture and Streams" compatible {@code getUserMedia}
     * implementation.
     * See: https://www.w3.org/TR/mediacapture-streams/#dom-mediadevices-enumeratedevices
     *
     * @param {*} constraints 
     * @returns {Promise}
     */
    getUserMedia(constraints) {
        return getUserMedia(constraints);
    }
}

export default new MediaDevices();
