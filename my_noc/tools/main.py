from my_noc.tools.io import to_csv, from_json
from my_noc.tools.plots import generate_plot


class Experiment:
    def __init__(self, packet_injection_rate, aco_packet_injection_rate, result_dir, traffic, routing, selection):
        self.packet_injection_rate = packet_injection_rate
        self.aco_packet_injection_rate = aco_packet_injection_rate
        self.result_dir = result_dir
        self.traffic = traffic
        self.routing = routing
        self.selection = selection

    def load_stats(self):
        """
        Load the statistics from the result directory.
        :return: None
        """
        self.stats = from_json(self.result_dir + '/' + 'stats.json')


if __name__ == '__main__':
    traffics = ['uniform', 'transpose', 'hotspot']
    packet_injection_rates = [1, 5, 10, 20, 50]

    for traffic in traffics:
        experiments = []

        for packet_injection_rate in packet_injection_rates:
            experiments.append(Experiment(
                packet_injection_rate=packet_injection_rate,
                aco_packet_injection_rate=100,
                result_dir='../results/j_{}/t_{}/r_{}/s_{}/'.format(packet_injection_rate, traffic, 'xy', 'random'),
                traffic=traffic,
                routing='xy',
                selection='random',
            ))

            experiments.append(Experiment(
                packet_injection_rate=packet_injection_rate,
                aco_packet_injection_rate=packet_injection_rate,
                result_dir='../results/j_{}/t_{}/r_{}/s_{}/'.format(packet_injection_rate, traffic, 'odd_even', 'random'),
                traffic=traffic,
                routing='odd_even',
                selection='random',
            ))

            experiments.append(Experiment(
                packet_injection_rate=packet_injection_rate,
                aco_packet_injection_rate=packet_injection_rate,
                result_dir='../results/j_{}/t_{}/r_{}/s_{}/'.format(packet_injection_rate, traffic, 'odd_even', 'buffer_level'),
                traffic=traffic,
                routing='odd_even',
                selection='buffer_level',
            ))

            experiments.append(Experiment(
                packet_injection_rate=packet_injection_rate,
                aco_packet_injection_rate=packet_injection_rate,
                result_dir='../results/j_{}/t_{}/r_{}/s_{}/'.format(packet_injection_rate, traffic, 'odd_even', 'aco'),
                traffic=traffic,
                routing='odd_even',
                selection='aco',
            ))

        for experiment in experiments:
            experiment.load_stats()
            
        to_csv('../results/t_{}.csv'.format(traffic), experiments, [
            ('Traffic', lambda e: e.traffic),
            ('Packet Injection Rate (packets/cycle/node)', lambda e: float(e.packet_injection_rate) / 100),
            ('Routing Algorithm', lambda e: e.routing),
            ('Selection Policy', lambda e: e.selection),
            ('Routing+Selection', lambda e: '{}+{}'.format(e.routing, e.selection)),
            ('Total Cycles', lambda e: e.stats['total_cycles']),
            ('# Packets Transmitted', lambda e: e.stats['packet.num_packets_transmitted']),
            ('Throughput (packets/cycle/node)', lambda e: e.stats['packet.throughput']),
            ('Average Packet Delay (cycles)', lambda e: e.stats['packet.average_packet_delay']),
            ('Normal.# Packets Transmitted', lambda e: e.stats[
                'packet.num_packets_transmitted'] if 'packet.num_packets_transmitted' in e.stats else ''),
            ('Normal.Throughput (packets/cycle/node)', lambda e: e.stats['packet.throughput'] if 'packet.throughput' in e.stats else ''),
            ('Normal.Average Packet Delay (cycles)', lambda e: e.stats[
                'packet.average_packet_delay'] if 'packet.average_packet_delay' in e.stats else ''),
            ('ACO.# Packets Transmitted', lambda e: e.stats[
                'acopacket.num_packets_transmitted'] if 'acopacket.num_packets_transmitted' in e.stats else ''),
            ('ACO.Throughput (packets/cycle/node)', lambda e: e.stats['acopacket.throughput'] if 'acopacket.throughput' in e.stats else ''),
            ('ACO.Average Packet Delay (cycles)', lambda e: e.stats[
                'acopacket.average_packet_delay'] if 'acopacket.average_packet_delay' in e.stats else ''),
        ])

        generate_plot(
            '../results/t_{}.csv'.format(traffic),
            '../results/t_{}_throughput.pdf'.format(traffic),
            'Packet Injection Rate (packets/cycle/node)',
            'Routing+Selection',
            'Throughput (packets/cycle/node)'
        )

        generate_plot(
            '../results/t_{}.csv'.format(traffic),
            '../results/t_{}_normal_throughput.pdf'.format(traffic),
            'Packet Injection Rate (packets/cycle/node)',
            'Routing+Selection',
            'Normal.Throughput (packets/cycle/node)'
        )

        generate_plot(
            '../results/t_{}.csv'.format(traffic),
            '../results/t_{}_aco_throughput.pdf'.format(traffic),
            'Packet Injection Rate (packets/cycle/node)',
            'Routing+Selection',
            'ACO.Throughput (packets/cycle/node)'
        )

        generate_plot(
            '../results/t_{}.csv'.format(traffic),
            '../results/t_{}_average_packet_delay.pdf'.format(traffic),
            'Packet Injection Rate (packets/cycle/node)',
            'Routing+Selection',
            'Average Packet Delay (cycles)'
        )

        generate_plot(
            '../results/t_{}.csv'.format(traffic),
            '../results/t_{}_normal_average_packet_delay.pdf'.format(traffic),
            'Packet Injection Rate (packets/cycle/node)',
            'Routing+Selection',
            'Normal.Average Packet Delay (cycles)'
        )

        generate_plot(
            '../results/t_{}.csv'.format(traffic),
            '../results/t_{}_aco_average_packet_delay.pdf'.format(traffic),
            'Packet Injection Rate (packets/cycle/node)',
            'Routing+Selection',
            'ACO.Average Packet Delay (cycles)'
        )