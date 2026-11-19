import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var conexion = Conexion()
    @AppStorage("ip") private var ip = ""
    @AppStorage("clave") private var clave = ""

    @State private var modo = 0
    @State private var sensPad = 1.6
    @State private var sensAire = 20.0
    @State private var invH = false
    @State private var invV = false
    @State private var bloqueado = false
    @State private var presionado = false
    @State private var brillo = 50.0
    @State private var aereo = MouseAereo()
    @State private var tecladoActivo = false

    private enum Campo { case ip, clave }
    @FocusState private var campo: Campo?   // qué campo tiene el teclado abierto

    var body: some View {
        VStack(spacing: 10) {
            cabecera

            Picker("Modo", selection: $modo) {
                Text("Trackpad").tag(0)
                Text("Mouse aéreo").tag(1)
            }
            .pickerStyle(.segmented)

            if tecladoActivo {
                panelTeclado
            }

            if modo == 0 {
                panelTrackpad
            } else {
                panelAereo
            }

            botonesClic
            panelVolumen
        }
        .padding()
        .preferredColorScheme(.dark)
        .onChange(of: conexion.conectado) { conectado in
            if conectado { campo = nil }   // al conectar, se esconde el teclado
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true   // que no se apague la pantalla
            aereo.conexion = conexion
            if !ip.isEmpty { conexion.conectar(ip: ip, clave: clave) }
        }
    }

    private func conectarYCerrarTeclado() {
        campo = nil
        conexion.conectar(ip: ip, clave: clave)
    }

    private var cabecera: some View {
        VStack(spacing: 6) {
            HStack {
                TextField("IP del PC", text: $ip)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .focused($campo, equals: .ip)
                    .submitLabel(.next)
                    .onSubmit { campo = .clave }
                SecureField("Clave", text: $clave)
                    .textFieldStyle(.roundedBorder)
                    .focused($campo, equals: .clave)
                    .submitLabel(.go)
                    .onSubmit { conectarYCerrarTeclado() }
                Button("Conectar") {
                    conectarYCerrarTeclado()
                }
                .buttonStyle(.borderedProminent)
            }
            Text(conexion.conectado ? "Conectado" : "Desconectado")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var panelTrackpad: some View {
        VStack {
            SuperficieTrackpad(conexion: conexion, sensibilidad: sensPad)
            HStack {
                Text("Sensibilidad").font(.footnote)
                Slider(value: $sensPad, in: 0.5...4)
            }
        }
    }

    private var panelAereo: some View {
        VStack(spacing: 8) {
            Text(presionado ? "Moviendo..." : "Mantén presionado y apunta")
                .font(.title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(presionado ? Color.blue : Color(red: 0.12, green: 0.23, blue: 0.54))
                .cornerRadius(16)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !presionado {
                                presionado = true
                                aereo.sensibilidad = sensAire
                                aereo.invertirH = invH
                                aereo.invertirV = invV
                                aereo.empezar()
                            }
                        }
                        .onEnded { _ in
                            presionado = false
                            aereo.parar()
                        }
                )
            HStack {
                Text("Sensibilidad").font(.footnote)
                Slider(value: $sensAire, in: 5...60)
            }
            HStack {
                Toggle("Invertir H", isOn: $invH)
                Toggle("Invertir V", isOn: $invV)
            }
            .font(.footnote)
        }
    }

    private var botonesClic: some View {
        HStack {
            Button("Clic izq.") { conexion.enviar(["t": "clic", "b": "izq"]) }
            Button("Clic der.") { conexion.enviar(["t": "clic", "b": "der"]) }
            Button(bloqueado ? "Soltar" : "Arrastrar") {
                bloqueado.toggle()
                conexion.enviar(["t": bloqueado ? "abajo" : "arriba", "b": "izq"])
            }
            .tint(bloqueado ? Color.blue : Color.gray)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // el campo solo aparece con el teclado activado; al apagarlo desaparece y se cierra el teclado
    private var panelTeclado: some View {
        VStack(spacing: 6) {
            EntradaTeclado(conexion: conexion)
                .frame(height: 38)
            HStack {
                teclaEspecial("⌫", "borrar")
                teclaEspecial("Enter", "enter")
                teclaEspecial("Tab", "tab")
                teclaEspecial("Esc", "esc")
            }
            HStack {
                teclaEspecial("←", "izq")
                teclaEspecial("↑", "arriba")
                teclaEspecial("↓", "abajo")
                teclaEspecial("→", "der")
            }
        }
    }

    private func teclaEspecial(_ titulo: String, _ nombre: String) -> some View {
        Button(titulo) { conexion.enviar(["t": "tecla", "k": nombre]) }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }

    private var panelVolumen: some View {
        VStack {
            Button(tecladoActivo ? "Teclado: ON" : "Teclado: OFF") {
                tecladoActivo.toggle()
                if tecladoActivo { campo = nil }
            }
            .buttonStyle(.borderedProminent)
            .tint(tecladoActivo ? Color.blue : Color.gray)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            HStack {
                Button("Vol −") { conexion.enviar(["t": "vol", "a": "bajar"]) }
                Button("Silencio") { conexion.enviar(["t": "vol", "a": "silencio"]) }
                Button("Vol +") { conexion.enviar(["t": "vol", "a": "subir"]) }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            HStack {
                Text("Brillo").font(.footnote)
                Slider(value: $brillo, in: 0...100, step: 5) { editando in
                    if !editando { conexion.enviar(["t": "brillo", "v": Int(brillo)]) }
                }
            }
        }
    }
}
