// Я реализовал пункт 6 "Если лимит превышен, то возвращать уникальное сообщение о том, что лимит превышен"
// данным образом: если лимит превышен, то в HTTP-ответ вместе с обычным текстом ответа
// добавляется уникальное сообщение "Лимит превышен! Попробуйте позже! "
// далее обработка выполняется в обычном режиме (как если бы превышения лимита не было бы).

package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"
)

// Объявление глобальных переменных.
// Массив positiveStatusCodes содержит положительные HTTP-статусы (200, 202).
// Массив negativeStatusCodes содержит отрицательные HTTP-статусы (400, 500).
// Канал requestTokenBucket с буфером на 5 токенов используется для ограничения 5 запросов в секунду.
var (
	positiveStatusCodes = []int{http.StatusOK, http.StatusAccepted}
	negativeStatusCodes = []int{http.StatusBadRequest, http.StatusInternalServerError}
	requestTokenBucket  = make(chan struct{}, 5)
)

// Объявляются структуры для хранения статистики.
// Структура ClientStatsData хранит общее количество запросов от клиента и разбиение по HTTP-статусам.
// Глобальная структура GlobalServerStats с мьютексом хранит общее число положительных и отрицательных ответов
// и статистику по каждому клиенту.
type ClientStatsData struct {
	TotalNumberRequests  int         `json:"Всего запросов"`
	ResponseStatusCounts map[int]int `json:"Количество статусов"`
}

// Пункт 7. После того, как будут отправлены все запросы клиентами на сервер и даны ответы,
// необходимо посчитать количество положительных и отрицательных запросов
// 1. Всего для сервера
// 2. На каждого из клиентов
// И сохранить это в JSON, который можно будет потом получить с сервера по GET запросу

var GlobalServerStats = struct {
	sync.Mutex
	NumberTotalPositiveResponses int                         `json:"Всего позитивных"`
	NumberTotalNegativeResponses int                         `json:"Всего негативных"`
	ClientsStats                 map[string]*ClientStatsData `json:"Клиенты"`
}{
	ClientsStats: make(map[string]*ClientStatsData),
}

// Получается порт из переменной окружения SERVER_PORT (по стандарту - 8080).
// Запускается горутина для регулярного пополнения requestTokenBucket.
// Регистрируются обработчики: для POST-запросов по адресу /request, для GET-запросов по адресу /stats.
// Запускается HTTP-сервер на указанном порту.
func main() {
	// Пункт 1. Необходимо поднять сервер
	// Порт для сервера необходимо подтянуть из файла env

	port := os.Getenv("SERVER_PORT")
	if port == "" {
		port = "8080"
	}

	go fillRequestTokenBucket()

	// Пункт 2. Сервер может принимать GET и POST запросы

	http.HandleFunc("/request", handlePostRequest)
	http.HandleFunc("/stats", handleStatsRequest)

	log.Println("Сервер работает. Порту", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

// Пункт 6. Ограничить пропускную способность сервера

// Функция fillRequestTokenBucket пополняет requestTokenBucket токенами.
// Создаётся таймер, срабатывающий 5 раз в секунду.
// Если в bucket ещё есть место, то при каждом срабатывании таймера добавляется токен.
func fillRequestTokenBucket() {
	fiveRequestsTimer := time.NewTicker(time.Second / 5)
	defer fiveRequestsTimer.Stop()
	for {
		<-fiveRequestsTimer.C
		select {
		case requestTokenBucket <- struct{}{}:
		default:
		}
	}
}

// Функция handlePostRequest обрабатывает входящие POST-запросы от клиентов.
// Проверка на то, что метод запроса это POST, из заголовка извлекается Client-ID,
// производится попытка взять токен из requestTokenBucket (если не получается - значит лимит превышен).
// Если лимит превышен - в ответ добавляется уникальное сообщение.
// Генерируется случайный HTTP-статус: с вероятностью 70% - положительный, с вероятностью 30% - отрицательный.
// Отправляется ответ клиенту и обновляется глобальная статистика сервера.
func handlePostRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Внимание! Разрешен только 'POST'!", http.StatusMethodNotAllowed)
		return
	}

	clientID := r.Header.Get("Client-ID")
	if clientID == "" {
		http.Error(w, "Внимание! Необходим ID клиента!", http.StatusBadRequest)
		return
	}

	// Часть 6 пункта

	var isLimitExceeded bool
	select {
	case <-requestTokenBucket:
	default:
		log.Println("Внимание! Лимит превышен для клиента!", clientID)
		isLimitExceeded = true
	}

	responseStatusCode := generateRandomStatusCode()
	w.WriteHeader(responseStatusCode)
	if isLimitExceeded {
		w.Write([]byte("Лимит превышен! Попробуйте позже! "))
	}
	w.Write([]byte("Запрос обработан."))

	// Часть 7 пункта

	GlobalServerStats.Lock()
	if responseStatusCode == http.StatusOK || responseStatusCode == http.StatusAccepted {
		GlobalServerStats.NumberTotalPositiveResponses++
	} else {
		GlobalServerStats.NumberTotalNegativeResponses++
	}
	if _, ok := GlobalServerStats.ClientsStats[clientID]; !ok {
		GlobalServerStats.ClientsStats[clientID] = &ClientStatsData{ResponseStatusCounts: make(map[int]int)}
	}
	GlobalServerStats.ClientsStats[clientID].TotalNumberRequests++
	GlobalServerStats.ClientsStats[clientID].ResponseStatusCounts[responseStatusCode]++
	GlobalServerStats.Unlock()
}

// Функция handleStatsRequest обрабатывает GET-запросы по адресу /stats и возвращает статистику сервера в формате JSON.
// Проверяется, что метод запроса это GET.
// Статистика кодируется в форматированный JSON и отправляется клиенту.
func handleStatsRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Внимание! Разрешён только 'GET'!", http.StatusMethodNotAllowed)
		return
	}
	GlobalServerStats.Lock()
	statsJSON, err := json.MarshalIndent(GlobalServerStats, "", "  ")
	GlobalServerStats.Unlock()
	if err != nil {
		http.Error(w, "Внимание! Ошибка генерации статистики!", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(statsJSON)
}

// Пункт 4. Сделать имитацию ответов сервера:
// Сервер в рандомном порядке будет 1 и 2 клиенту в ответ отправлять статусы:
// 70 положительных ответов, 30 отрицательных
// http.StatusOK (положительный статус)
// http.StatusAccepted (положительный статус)
// http.StatusBadRequest (отрицательный)
// http.StatusInternalServerError (отрицательный)

// Функция generateRandomStatusCode возвращает случайный HTTP-статус.
// С вероятностью 70% возвращается один из положительных статусов (200 или 202),
// с вероятностью 30% – один из отрицательных статусов (400 или 500).
func generateRandomStatusCode() int {
	if rand.Intn(100) < 70 {
		return positiveStatusCodes[rand.Intn(len(positiveStatusCodes))]
	}
	return negativeStatusCodes[rand.Intn(len(negativeStatusCodes))]
}
