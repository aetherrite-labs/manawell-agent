//
//  Exports.swift
//  ManawellAgentServer
//
//  The serving layer is always built on top of the collectors. Re-export them so that
//  anything linking ManawellAgentServer (the agentd binary, the macOS app in "host"
//  mode) gets the collector + cache types without a second import. A consumer that only
//  needs to read local usage links ManawellUsageCollectors directly instead.
//

@_exported import ManawellUsageCollectors
