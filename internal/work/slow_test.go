package work

import "testing"

func BenchmarkFib(b *testing.B) {
	// Benchmark de la versión lenta
	for i := 0; i < b.N; i++ {
		_ = Fib(30) // Valor más pequeño para que no tarde demasiado
	}
}

func BenchmarkFibFast(b *testing.B) {
	// Benchmark de la versión optimizada
	for i := 0; i < b.N; i++ {
		_ = FibFast(30)
	}
}

// Test para verificar que ambas funciones dan el mismo resultado
func TestFibEquality(t *testing.T) {
	tests := []int{0, 1, 2, 3, 4, 5, 10, 20}

	for _, n := range tests {
		slow := Fib(n)
		fast := FibFast(n)

		if slow != fast {
			t.Errorf("Fib(%d) = %d, FibFast(%d) = %d", n, slow, n, fast)
		}
	}
}
