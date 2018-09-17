# shaper
Wymagane oprogramowanie: iptables, ipset, iproute2.

Plik musi zaczynać się od deklaracji poniższych parametrów. Jeśli te parametry nie zostaną podane, zostaną użyte domyślne parametry określone w pliku fw.conf.

ISP_RX_LIMIT=470000kbit</br>
ISP_TX_LIMIT=470000kbit</br>
GW_TO_LAN_RATE_LIMIT=100kbit</br>
GW_TO_LAN_CEIL_LIMIT=200000kbit</br>
GW_TO_WAN_RATE_LIMIT=100kbit</br>
GW_TO_WAN_CEIL_LIMIT=50000kbit</br>
LAN_UNCLASSIFIED_RATE_LIMIT=16kbit</br>
LAN_UNCLASSIFIED_CEIL_LIMIT=128kbit</br>
WAN_UNCLASSIFIED_RATE_LIMIT=16kbit</br>
WAN_UNCLASSIFIED_CEIL_LIMIT=128kbit</br>
GW_TO_LAN_PRIORITY=2</br>
GW_TO_WAN_PRIORITY=2</br>
LAN_UNCLASSIFIED_PRIORITY=7</br>
WAN_UNCLASSIFIED_PRIORITY=7</br>
LAN_HOSTS_PRIORITY=2</br>
WAN_HOSTS_PRIORITY=2</br>

ISP_RX_LIMIT oraz ISP_TX_LIMIT to wynikające z kontraktu z operatorem nadrzędnym parametry łącza dostępowego do sieci Internet pomniejszone o ok 5-10% aby uniknąc zapełniania kolejki modemu operatora.</br>

GW_TO_LAN_RATE_LIMIT to gwarantowana prędkość dla ruchu wychodzącego do sieci LAN, którego źródłem jest Gateway na którym pracuje skrypt fw.sh</br>

GW_TO_LAN_CEIL_LIMIT to limit ruchu wychodzącego do sieci LAN, którego źródłem jest Gateway na którym pracuje skrypt fw.sh</br>

GW_TO_WAN_RATE_LIMIT to gwarantowana prędkośc dla ruchu wychodzącego do sieci WAN, którego źródłem jest Gateway na którym pracuje skrypt fw.sh</br>

GW_TO_WAN_CEIL_LIMIT to limit ruchu wychodzącego do sieci WAN, którego źródłem jest Gateway na którym pracuje skrypt fw.sh</br>

LAN_UNCLASSIFIED_RATE_LIMIT to gwarantowana prędjość dla ruchu wychodzącego do sieci LAN nie sklasyfikowanego, czyli komputerów urządzeń nie ujętych w pliku konfiguracyjnym dla modułu Shaper</br>

LAN_UNCLASSIFIED_CEIL_LIMIT to limit dla ruchu wychodzącego do sieci LAN nie sklasyfikowanego, czyli komputerów urządzeń nie ujętych w pliku konfiguracyjnym dla modułu Shape</br>

WAN_UNCLASSIFIED_RATE_LIMIT to gwarantowana prędkość dla ruchu wychodzącego do sieci WAN nie sklasyfikowanego, czyli komputerów urządzeń nie ujętych w pliku konfiguracyjnym dla modułu Shaper</br>

WAN_UNCLASSIFIED_CEIL_LIMIT to limit dla ruchu wychodzącego do sieci WAN nie sklasyfikowanego, czyli komputerów urządzeń nie ujętych w pliku konfiguracyjnym dla modułu Shaper</br>

W siedmiostopniowej skali od 1 do 7 gdzie 1 oznacza najwyższy prioryter a 7 najniższy okraślane sa także prirytety dla nastepującyh grup.</br>

GW_TO_LAN_PRIORITY - proprytet dla pakietów wysyłanych z GW do sieci LAN.</br>

GW_TO_WAN_PRIORITY - proprytet dla pakietów wysyłanych z GW do sieci WAN.</br>

LAN_UNCLASSIFIED_PRIORITY - proprytet dla pakietów nie sklasyfikowanych wysyłanych do sieci LAN.</br>

WAN_UNCLASSIFIED_PRIORITY - proprytet dla pakietów nie sklasyfikowanych wysyłanych do sieci WAN.</br>

LAN_HOSTS_PRIORITY - proprytet dla pakietów wysyłanych do sieci LAN, kierowanych do hostów dla, których ruchem zarządza moduł shaper.</br>

WAN_HOSTS_PRIORITY - proprytet dla pakietów wysyłanych do sieci WAN, kierowanych z hostów dla, których ruchem zarządza moduł shaper.</br>

Następnie dla każdego hosta powinny być określone parametry klas UP/DOWN HTB, przy czym kilka hostów może być przypisanych do jednej pary klasy HTB.</br>

Przykładowa konfiguracja dla jednego hosta przypisanego do jednej pary klas UP/DOWN:

#konfiguracja komputerów klientów customer 1

class_up 8kbit 1024kbit</br>
class_down 8kbit 5120kbit</br>
filter 192.168.101.24</br>

dla kilku hostów przypisanych do pary klas:

customer 2</br>
class_up 8kbit 1024kbit</br>
class_down 8kbit 5120kbit</br>
filter 192.168.10.24</br>
filter 192.168.10.25</br>
filter 192.168.10.26</br>

Klient może mieć kilka taryf (kilka umów na usługi) i przypisane do nich różne komputery. Wtedy dla każdej taryfy trzeba wygenerować odpowiedni zestaw rekordów. Np jeśli klient o id 1 miałby jeszcze dwie dodatkowe umowy/taryfy z przypisanymi do nich po po jednym modemie/komputerze, należy dodać następujące rekordy

customer 1</br>
class_up 8kbit 1024kbit</br>
class_down 8kbit 5120kbit</br>
filter 192.168.101.30</br>
customer 1</br>
class_up 8kbit 1024kbit</br>
class_down 8kbit 5120kbit</br>
filter 192.168.101.34</br>

Znak "#" oznacza komentarz i nie jest parsowany przez moduł shaper. Cyfra po słowie customer to unikalne id klienta w LMS. Wyrażenia class_up oraz class_down mają jako parametry rate oraz ceil, gdzie RATE to jest minimalna gwarantowana prędkość, a CEIL to maksymalna niegwarantowana prędkość. Wyrażenie filter jako parametr ma adres ip hosta, którego dotyczy konfiguracja.

Taki plik może wygenerować odpowiednio skonfigurowany LMS z wykorzystaniem instancji lmsd o nazwie tc-new.
