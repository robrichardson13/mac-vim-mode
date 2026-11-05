import AppKit

setvbuf(stdout, nil, _IOLBF, 0)

let application = NSApplication.shared
application.setActivationPolicy(.accessory)

let appController = AppController()
appController.start()
application.run()
