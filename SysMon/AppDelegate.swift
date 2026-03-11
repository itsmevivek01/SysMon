//
//  AppDelegate.swift
//  SysMon
//
//  Created by Vivek Krishnan on 11/03/26.
//
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var cpuLabel: NSTextField!
    var infoLabel: NSTextField!

    // CPU tick history
    var previousUser: Double = 0
    var previousSystem: Double = 0
    var previousIdle: Double = 0
    var previousNice: Double = 0

    // Toggle flag
    var showRAM = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 40)

        // Stack view for labels
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

        cpuLabel = NSTextField(labelWithString: "CPU: --%")
        cpuLabel.font = NSFont.systemFont(ofSize: 9)
        cpuLabel.alignment = .center

        infoLabel = NSTextField(labelWithString: "--")
        infoLabel.font = NSFont.systemFont(ofSize: 9)
        infoLabel.alignment = .center

        stackView.addArrangedSubview(cpuLabel)
        stackView.addArrangedSubview(infoLabel)

        statusItem.button?.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: statusItem.button!.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: statusItem.button!.centerYAnchor)
        ])

        // Menu with toggle + quit
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle RAM/Disk", action: #selector(toggleDisplay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Timer to update stats
        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateStats), userInfo: nil, repeats: true)
    }

    @objc func toggleDisplay() {
        showRAM.toggle()
    }

    @objc func updateStats() {
        let cpuUsage = getSystemCPUUsage()

        if showRAM {
            let mem = getMemoryUsage()
            let percent = Int((Double(mem.used) / Double(mem.total)) * 100.0)
            cpuLabel.stringValue = "CPU: \(cpuUsage)%"
            infoLabel.stringValue = "RAM: \(percent)%"
        } else {
            let disk = getDiskFreeSpace()
            cpuLabel.stringValue = "CPU: \(cpuUsage)%"
            infoLabel.stringValue = "DSK: \(disk.free)GB"
        }
    }

    // MARK: - CPU
    func getSystemCPUUsage() -> Int {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if result != KERN_SUCCESS { return -1 }

        let user = Double(load.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3)

        let userDiff = user - previousUser
        let systemDiff = system - previousSystem
        let idleDiff = idle - previousIdle
        let niceDiff = nice - previousNice

        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        let usedTicks = userDiff + systemDiff + niceDiff

        previousUser = user
        previousSystem = system
        previousIdle = idle
        previousNice = nice

        if totalTicks == 0 { return 0 }
        return Int((usedTicks / totalTicks) * 100.0)
    }

    // MARK: - Memory
    func getMemoryUsage() -> (used: Int, total: Int) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result != KERN_SUCCESS { return (0,0) }

        let pageSize = vm_kernel_page_size
        let free = UInt64(stats.free_count) * UInt64(pageSize)
        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)

        let used = active + inactive + wired
        let total = used + free

        return (Int(used / (1024*1024)), Int(total / (1024*1024))) // MB
    }

    // MARK: - Disk
    func getDiskFreeSpace() -> (free: Int, total: Int) {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            let free = attrs[.systemFreeSize] as? Int64 ?? 0
            let total = attrs[.systemSize] as? Int64 ?? 0
            return (Int(free / (1024*1024*1024)), Int(total / (1024*1024*1024))) // GB
        }
        return (0,0)
    }
}
