import Darwin
import Foundation

protocol SystemMediaControlling {
    func pauseIfPlaying() throws -> Bool
    func resume() throws
}

enum SystemMediaControlError: Error {
    case mediaRemoteUnavailable
    case playbackStateUnavailable
}

final class MediaRemoteMediaController: SystemMediaControlling {
    private typealias IsPlayingCallback = @convention(block) (Bool) -> Void
    private typealias GetIsPlayingFunction =
        @convention(c) (DispatchQueue, @escaping IsPlayingCallback) -> Void
    private typealias SendCommandFunction = @convention(c) (Int32, CFDictionary?) -> Void

    private static let playCommand: Int32 = 0
    private static let pauseCommand: Int32 = 1

    private let getIsPlaying: GetIsPlayingFunction
    private let sendCommand: SendCommandFunction
    private let stateTimeout: TimeInterval

    init(stateTimeout: TimeInterval = 0.25) throws {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            throw SystemMediaControlError.mediaRemoteUnavailable
        }

        guard
            let getIsPlayingSymbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying"),
            let sendCommandSymbol = dlsym(handle, "MRMediaRemoteSendCommand")
        else {
            throw SystemMediaControlError.mediaRemoteUnavailable
        }

        self.getIsPlaying = unsafeBitCast(getIsPlayingSymbol, to: GetIsPlayingFunction.self)
        self.sendCommand = unsafeBitCast(sendCommandSymbol, to: SendCommandFunction.self)
        self.stateTimeout = stateTimeout
    }

    convenience init?() {
        do {
            try self.init(stateTimeout: 0.25)
        } catch {
            AppLogger.warning(
                "MediaRemote unavailable; media pause while recording disabled",
                category: AppLogger.audio
            )
            return nil
        }
    }

    func pauseIfPlaying() throws -> Bool {
        guard try isPlaying() else { return false }

        sendCommand(Self.pauseCommand, nil)
        return true
    }

    func resume() throws {
        sendCommand(Self.playCommand, nil)
    }

    private func isPlaying() throws -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Bool?

        getIsPlaying(.main) { isPlaying in
            result = isPlaying
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + stateTimeout
        guard semaphore.wait(timeout: timeout) == .success, let result else {
            throw SystemMediaControlError.playbackStateUnavailable
        }

        return result
    }
}
