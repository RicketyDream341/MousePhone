import Foundation

// Maneja la conexión WebSocket con el servidor que corre en el PC
final class Conexion: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var conectado = false

    private var sesion: URLSession!
    private var tarea: URLSessionWebSocketTask?
    private var ip = ""
    private var clave = ""
    private var quiereConexion = false

    override init() {
        super.init()
        sesion = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    func conectar(ip: String, clave: String) {
        self.ip = ip
        self.clave = clave
        quiereConexion = true
        abrir()
    }

    private func abrir() {
        let vieja = tarea
        tarea = nil
        vieja?.cancel(with: .goingAway, reason: nil)

        let k = clave.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clave
        guard let url = URL(string: "ws://\(ip):8080/ws?k=\(k)") else { return }
        tarea = sesion.webSocketTask(with: url)
        tarea?.resume()
    }

    func enviar(_ datos: [String: Any]) {
        guard conectado,
              let json = try? JSONSerialization.data(withJSONObject: datos),
              let texto = String(data: json, encoding: .utf8) else { return }
        tarea?.send(.string(texto)) { _ in }
    }

    // si se cae la conexión, reintenta cada 1.5 segundos
    private func reintentar(de t: URLSessionTask) {
        guard t === tarea else { return }
        tarea = nil
        conectado = false
        guard quiereConexion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self, self.quiereConexion, self.tarea == nil else { return }
            self.abrir()
        }
    }

    // MARK: delegados de URLSession

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol proto: String?) {
        if webSocketTask === tarea { conectado = true }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        reintentar(de: webSocketTask)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        reintentar(de: task)
    }
}
