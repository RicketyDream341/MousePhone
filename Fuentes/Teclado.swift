import SwiftUI
import UIKit

// Campo de texto que no guarda nada: lo que escribes en el iPhone se manda directo al PC
struct EntradaTeclado: UIViewRepresentable {
    var conexion: Conexion

    func makeCoordinator() -> Coordinator {
        Coordinator(conexion)
    }

    func makeUIView(context: Context) -> CampoCaptura {
        let campo = CampoCaptura()
        campo.delegate = context.coordinator
        campo.placeholder = "Escribe aquí, se envía al PC"
        campo.borderStyle = .roundedRect

        // sin autocorrección ni sugerencias: el PC debe recibir exactamente lo que tecleas
        campo.autocorrectionType = .no
        campo.spellCheckingType = .no
        campo.autocapitalizationType = .none
        campo.smartQuotesType = .no
        campo.smartDashesType = .no
        campo.smartInsertDeleteType = .no

        let coordinador = context.coordinator
        campo.alBorrar = { coordinador.conexion.enviar(["t": "tecla", "k": "borrar"]) }

        DispatchQueue.main.async { campo.becomeFirstResponder() }
        return campo
    }

    func updateUIView(_ campo: CampoCaptura, context: Context) {
        context.coordinator.conexion = conexion
    }

    static func dismantleUIView(_ campo: CampoCaptura, coordinator: Coordinator) {
        campo.resignFirstResponder()
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var conexion: Conexion

        init(_ conexion: Conexion) {
            self.conexion = conexion
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            if !string.isEmpty {
                conexion.enviar(["t": "texto", "s": string])
            }
            return false   // el campo se queda vacío, todo va directo al PC
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            conexion.enviar(["t": "tecla", "k": "enter"])
            return false   // no se cierra el teclado
        }
    }
}

// como el campo siempre está vacío, cada borrar del teclado llega aquí
final class CampoCaptura: UITextField {
    var alBorrar: (() -> Void)?

    override func deleteBackward() {
        alBorrar?()
        super.deleteBackward()
    }
}
