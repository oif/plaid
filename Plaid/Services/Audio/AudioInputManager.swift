import Foundation
import AVFoundation
import CoreAudio

struct AudioInputDevice: Identifiable, Hashable, Codable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let isDefault: Bool
    
    static let systemDefault = AudioInputDevice(
        id: 0,
        name: "System Default",
        uid: "system_default",
        isDefault: true
    )
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: AudioInputDevice, rhs: AudioInputDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

@MainActor
class AudioInputManager: ObservableObject {
    static let shared = AudioInputManager()
    
    @Published private(set) var availableDevices: [AudioInputDevice] = []
    @Published var selectedDevice: AudioInputDevice = .systemDefault
    
    private init() {
        refreshDevices()
    }
    
    func refreshDevices() {
        var devices: [AudioInputDevice] = [.systemDefault]
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { 
            availableDevices = devices
            return 
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else { 
            availableDevices = devices
            return 
        }
        
        let defaultInputID = getDefaultInputDeviceID()
        
        for deviceID in deviceIDs {
            if hasInputChannels(deviceID: deviceID) {
                if let device = createAudioInputDevice(deviceID: deviceID, defaultID: defaultInputID) {
                    devices.append(device)
                }
            }
        }
        
        availableDevices = devices
        
        if !devices.contains(where: { $0.uid == selectedDevice.uid }) {
            selectedDevice = .systemDefault
        }
    }
    
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        
        guard status == noErr, dataSize > 0 else { return false }
        
        let bufferListPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferListPtr.deallocate() }
        
        let result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPtr)
        guard result == noErr else { return false }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        var channelCount: UInt32 = 0
        for buffer in bufferList {
            channelCount += buffer.mNumberChannels
        }
        
        return channelCount > 0
    }
    
    private func createAudioInputDevice(deviceID: AudioDeviceID, defaultID: AudioDeviceID) -> AudioInputDevice? {
        guard let name = getDeviceName(deviceID: deviceID),
              let uid = getDeviceUID(deviceID: deviceID) else {
            return nil
        }
        
        return AudioInputDevice(
            id: deviceID,
            name: name,
            uid: uid,
            isDefault: deviceID == defaultID
        )
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)
        return status == noErr ? name as String : nil
    }
    
    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &uid)
        return status == noErr ? uid as String : nil
    }
    
    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        
        return deviceID
    }
    
    func setInputDevice(for engine: AVAudioEngine, device: AudioInputDevice) throws {
        if device.uid == AudioInputDevice.systemDefault.uid {
            return
        }
        
        #if os(macOS)
        let audioUnit = engine.inputNode.audioUnit!
        var deviceID = device.id
        
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if status != noErr {
            throw AudioInputError.failedToSetDevice
        }
        #endif
    }
    
}

enum AudioInputError: Error, LocalizedError {
    case failedToSetDevice
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedToSetDevice: return "Failed to set audio input device"
        case .deviceNotFound: return "Audio input device not found"
        }
    }
}
