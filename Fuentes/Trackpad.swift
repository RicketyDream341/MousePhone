import SwiftUI
import UIKit

// Superficie táctil: misma lógica que el trackpad de la versión web
struct SuperficieTrackpad: UIViewRepresentable {
    var conexion: Conexion
    var sensibilidad: Double

    func makeUIView(context: Context) -> VistaTrackpad {
        let vista = VistaTrackpad()
        vista.isMultipleTouchEnabled = true
        vista.backgroundColor = UIColor(white: 0.12, alpha: 1)
        vista.layer.cornerRadius = 16
        return vista
    }

    func updateUIView(_ vista: VistaTrackpad, context: Context) {
        vista.conexion = conexion
        vista.sensibilidad = sensibilidad
    }
}

final class VistaTrackpad: UIView {
    var conexion: Conexion?
    var sensibilidad = 1.6

    private var ultimo = CGPoint.zero
    private var tInicio = Date()
    private var distancia: CGFloat = 0
    private var maxDedos = 0
    private var tUltimoToque = Date.distantPast
    private var arrastrando = false
    private var resto = CGPoint.zero

    // dedos que siguen apoyados en la pantalla
    private func activos(_ event: UIEvent?, _ touches: Set<UITouch>) -> Set<UITouch> {
        let todos = event?.allTouches ?? touches
        return todos.filter { $0.phase != .ended && $0.phase != .cancelled }
    }

    private func puntoMedio(_ toques: Set<UITouch>) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for t in toques {
            let p = t.location(in: self)
            x += p.x
            y += p.y
        }
        let n = CGFloat(max(toques.count, 1))
        return CGPoint(x: x / n, y: y / n)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let a = activos(event, touches)
        if a.count == 1 {
            tInicio = Date()
            distancia = 0
            maxDedos = 1
            // un toque justo después de otro = arrastrar (o doble clic si no te mueves)
            if Date().timeIntervalSince(tUltimoToque) < 0.3 {
                arrastrando = true
                conexion?.enviar(["t": "abajo", "b": "izq"])
            }
        }
        maxDedos = max(maxDedos, a.count)
        ultimo = puntoMedio(a)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let a = activos(event, touches)
        guard !a.isEmpty else { return }
        let p = puntoMedio(a)
        let dx = p.x - ultimo.x
        let dy = p.y - ultimo.y
        ultimo = p
        distancia += hypot(dx, dy)

        if a.count >= 2 {
            conexion?.enviar(["t": "scroll", "dy": Double(dy)])
        } else {
            mandarMovimiento(Double(dx) * sensibilidad, Double(dy) * sensibilidad)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activos(event, touches).isEmpty else { return }
        terminar()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activos(event, touches).isEmpty else { return }
        terminar()
    }

    private func terminar() {
        if arrastrando {
            conexion?.enviar(["t": "arriba", "b": "izq"])
            arrastrando = false
            tUltimoToque = Date.distantPast
        } else if distancia < 8 && Date().timeIntervalSince(tInicio) < 0.25 {
            // un toque rápido y casi sin movimiento cuenta como clic
            conexion?.enviar(["t": "clic", "b": maxDedos >= 2 ? "der" : "izq"])
            if maxDedos < 2 { tUltimoToque = Date() }
        }
    }

    // el cursor se mueve en enteros, así que se guarda el sobrante de cada movimiento
    private func mandarMovimiento(_ dx: Double, _ dy: Double) {
        resto.x += CGFloat(dx)
        resto.y += CGFloat(dy)
        let ix = resto.x.rounded(.towardZero)
        let iy = resto.y.rounded(.towardZero)
        if ix != 0 || iy != 0 {
            resto.x -= ix
            resto.y -= iy
            conexion?.enviar(["t": "mover", "dx": Int(ix), "dy": Int(iy)])
        }
    }
}
