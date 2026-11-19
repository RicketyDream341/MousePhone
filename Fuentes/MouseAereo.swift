import CoreMotion

// Convierte el giro del iPhone en movimiento del cursor.
// CoreMotion da los ejes en el marco del celular (x a lo ancho, y a lo largo, z saliendo de la pantalla),
// así que aquí no hay confusión de ejes como en Safari.
final class MouseAereo {
    var conexion: Conexion?
    var sensibilidad = 20.0      // píxeles por grado
    var invertirH = false
    var invertirV = false

    private let motion = CMMotionManager()
    private var restoX = 0.0
    private var restoY = 0.0
    private var suaveX = 0.0
    private var suaveY = 0.0

    func empezar() {
        guard motion.isDeviceMotionAvailable else { return }
        suaveX = 0
        suaveY = 0
        motion.deviceMotionUpdateInterval = 1.0 / 100.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] datos, _ in
            guard let self = self, let d = datos else { return }
            self.procesar(d)
        }
    }

    func parar() {
        motion.stopDeviceMotionUpdates()
    }

    private func procesar(_ d: CMDeviceMotion) {
        let w = d.rotationRate   // rad/s
        let g = d.gravity
        let aGrados = 180.0 / Double.pi

        // giro alrededor de la vertical (izquierda/derecha): proyectar el giro sobre la gravedad
        // sirve sin importar cómo sostengas el celular
        var giroH = (w.x * g.x + w.y * g.y + w.z * g.z) * aGrados
        // subir o bajar la punta = giro alrededor del eje x del celular
        var giroV = -w.x * aGrados

        // zona muerta para que no tiemble con el pulso
        if abs(giroH) < 2 { giroH = 0 }
        if abs(giroV) < 2 { giroV = 0 }
        if invertirH { giroH = -giroH }
        if invertirV { giroV = -giroV }

        let dt = 0.01
        // suavizado simple para quitar saltos
        suaveX = suaveX * 0.5 + giroH * dt * sensibilidad * 0.5
        suaveY = suaveY * 0.5 + giroV * dt * sensibilidad * 0.5

        restoX += suaveX
        restoY += suaveY
        let ix = restoX.rounded(.towardZero)
        let iy = restoY.rounded(.towardZero)
        if ix != 0 || iy != 0 {
            restoX -= ix
            restoY -= iy
            conexion?.enviar(["t": "mover", "dx": Int(ix), "dy": Int(iy)])
        }
    }
}
