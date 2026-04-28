import Foundation
import Network

struct MCPServerSnapshot: Encodable {
    let generatedAt: String
    let displayName: String
    let dashboardURL: String
    let pricingURL: String
    let currentSource: String
    let statisticsDisplayMode: String
    let statusText: String
    let latestMessage: String
    let remaining: String
    let usage: String
    let renewal: String
    let progressLabel: String
    let progressPrefix: String?
    let usedPercent: Double?
    let email: String?
    let hasAPIKey: Bool
    let hasAGIKey: Bool
    let pollIntervalSeconds: Double
    let displayStyle: String
    let packageItems: [MCPPackageItem]
    let sourceGroups: [MCPSourceGroup]
}

struct MCPPackageItem: Encodable {
    let title: String
    let subtitle: String
    let badgeText: String
}

struct MCPSourceGroup: Encodable {
    let source: String
    let statusText: String
    let remaining: String
    let usage: String
    let renewal: String
    let progressValue: String
    let progressFraction: Double?
    let packageItems: [MCPPackageItem]
}

final class MCPSnapshotStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.yls.codex-monitor.mcp-snapshot-store")
    private var data = Data("{}".utf8)

    func get() -> Data {
        queue.sync { data }
    }

    func set(_ newData: Data) {
        queue.sync {
            data = newData
        }
    }
}

final class MCPHTTPServer: @unchecked Sendable {
    private let stateProvider: @Sendable () -> Data
    private let resourceURI = "yls://codex-monitor/snapshot"
    private let toolName = "get_codex_monitor_snapshot"
    private let queue = DispatchQueue(label: "com.yls.codex-monitor.mcp-server")
    private var listener: NWListener?
    private(set) var port: UInt16
    private(set) var isRunning = false
    var lastError: String?

    init(port: UInt16, stateProvider: @escaping @Sendable () -> Data) {
        self.port = port
        self.stateProvider = stateProvider
    }

    func updatePort(_ newPort: UInt16) throws {
        if newPort == port {
            if !isRunning {
                try start()
            }
            return
        }
        stop()
        port = newPort
        try start()
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                self?.lastError = nil
            case .failed(let error):
                self?.isRunning = false
                self?.lastError = error.localizedDescription
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.lastError = error.localizedDescription
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            if let request = self.parseHTTPRequest(from: buffer) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete {
                let response = self.makeJSONResponse([
                    "ok": false,
                    "error": "bad_request"
                ], status: "400 Bad Request")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            self.receiveRequest(on: connection, accumulated: buffer)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        let response: Data

        switch request.path {
        case "/", "/health":
            response = makeJSONResponse([
                "ok": true,
                "service": "yls-codex-monitor-mcp",
                "port": Int(port),
                "endpoints": ["/health", "/snapshot", "/mcp/snapshot", "/mcp"],
                "tool": toolName,
                "resource": resourceURI
            ])
        case "/snapshot", "/mcp/snapshot":
            response = makeRawJSONResponse(stateProvider())
        case "/mcp":
            response = handleMCPRequest(body: request.body)
        default:
            response = makeJSONResponse([
                "ok": false,
                "error": "not_found",
                "path": request.path
            ], status: "404 Not Found")
        }

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private struct HTTPRequest {
        let path: String
        let body: Data?
    }

    private func parseHTTPRequest(from requestData: Data) -> HTTPRequest? {
        guard let requestText = String(data: requestData, encoding: .utf8) else { return nil }
        let separator = "\r\n\r\n"
        let fallbackSeparator = "\n\n"

        let parts: [String]
        let headerBodySeparator: String
        if requestText.contains(separator) {
            parts = requestText.components(separatedBy: separator)
            headerBodySeparator = separator
        } else if requestText.contains(fallbackSeparator) {
            parts = requestText.components(separatedBy: fallbackSeparator)
            headerBodySeparator = fallbackSeparator
        } else {
            return nil
        }

        let header = parts.first ?? ""
        let bodyString = parts.dropFirst().joined(separator: headerBodySeparator)
        let firstLine = header.split(whereSeparator: \ .isNewline).first.map(String.init) ?? ""
        let components = firstLine.split(separator: " ")
        let path = components.count >= 2 ? String(components[1]).components(separatedBy: "?").first ?? "/" : "/"

        let contentLength = contentLengthFromHeader(header)
        let bodyData = Data(bodyString.utf8)
        if bodyData.count < contentLength {
            return nil
        }

        let finalBody = contentLength > 0 ? bodyData.prefix(contentLength) : Data()
        return HTTPRequest(path: path, body: finalBody.isEmpty ? nil : Data(finalBody))
    }

    private func contentLengthFromHeader(_ header: String) -> Int {
        for line in header.split(whereSeparator: \ .isNewline) {
            let raw = String(line)
            if raw.lowercased().hasPrefix("content-length:") {
                let value = raw.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
                return Int(value) ?? 0
            }
        }
        return 0
    }

    private func handleMCPRequest(body: Data?) -> Data {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return makeJSONResponse([
                "jsonrpc": "2.0",
                "error": [
                    "code": -32700,
                    "message": "Parse error"
                ],
                "id": NSNull()
            ])
        }

        let method = object["method"] as? String ?? ""
        let id = object["id"] ?? NSNull()
        let params = object["params"] as? [String: Any] ?? [:]
        let snapshotString = String(data: stateProvider(), encoding: .utf8) ?? "{}"

        let result: Any
        switch method {
        case "initialize":
            result = [
                "protocolVersion": "2024-11-05",
                "capabilities": [
                    "tools": [:],
                    "resources": [:]
                ],
                "serverInfo": [
                    "name": "yls-codex-monitor-mcp",
                    "version": "0.2.0"
                ]
            ]
        case "notifications/initialized":
            result = [:]
        case "tools/list":
            result = [
                "tools": [[
                    "name": toolName,
                    "description": "获取伊莉思 Codex 账户监控应用的最新本地快照数据",
                    "inputSchema": [
                        "type": "object",
                        "properties": [:]
                    ]
                ]]
            ]
        case "tools/call":
            let tool = params["name"] as? String ?? ""
            if tool == toolName {
                result = [
                    "content": [[
                        "type": "text",
                        "text": snapshotString
                    ]]
                ]
            } else {
                return makeJSONResponse([
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32601,
                        "message": "Unknown tool: \(tool)"
                    ],
                    "id": id
                ])
            }
        case "resources/list":
            result = [
                "resources": [[
                    "uri": resourceURI,
                    "name": "Codex Monitor Snapshot",
                    "description": "伊莉思 Codex 账户监控的最新本地快照",
                    "mimeType": "application/json"
                ]]
            ]
        case "resources/read":
            let uri = params["uri"] as? String ?? ""
            if uri == resourceURI {
                result = [
                    "contents": [[
                        "uri": resourceURI,
                        "mimeType": "application/json",
                        "text": snapshotString
                    ]]
                ]
            } else {
                return makeJSONResponse([
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32602,
                        "message": "Unknown resource: \(uri)"
                    ],
                    "id": id
                ])
            }
        default:
            return makeJSONResponse([
                "jsonrpc": "2.0",
                "error": [
                    "code": -32601,
                    "message": "Method not found: \(method)"
                ],
                "id": id
            ])
        }

        return makeJSONResponse([
            "jsonrpc": "2.0",
            "result": result,
            "id": id
        ])
    }

    private func makeJSONResponse(_ object: [String: Any], status: String = "200 OK") -> Data {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])) ?? Data("{}".utf8)
        return makeRawJSONResponse(body, status: status)
    }

    private func makeRawJSONResponse(_ body: Data, status: String = "200 OK") -> Data {
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Access-Control-Allow-Origin: *",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
