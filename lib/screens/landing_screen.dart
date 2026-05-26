import 'package:flutter/material.dart';
import 'auth_screen.dart';

class LandingScreen extends StatefulWidget {
	const LandingScreen({super.key});

	@override
	State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
	static const _pages = [
		_LandingPageData(
			icon: Icons.stacked_line_chart_rounded,
			title: 'Build better money habits',
			description:
					'Track your daily expenses, set savings goals, and stay on top '
					'of your budget with a calm, simple dashboard.',
		),
		_LandingPageData(
			icon: Icons.savings_rounded,
			title: 'Save with intention',
			description:
					'Create goals, schedule reminders, and celebrate progress as '
					'your savings grow each week.',
		),
		_LandingPageData(
			icon: Icons.insights_rounded,
			title: 'Understand your spending',
			description:
					'Spot patterns instantly with clean summaries and friendly '
					'visuals designed for everyday decisions.',
		),
	];

	final PageController _controller = PageController();
	int _index = 0;

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		const brandColor = Color(0xFFB38AF7);


		void openAuth({required bool showLogin}) {
			Navigator.of(context).push(
				MaterialPageRoute(
					builder: (_) => AuthScreen(showLogin: showLogin),
				),
			);
		}

		void handlePrimaryAction() {
			if (_index < _pages.length - 1) {
				_controller.nextPage(
					duration: const Duration(milliseconds: 350),
					curve: Curves.easeOutCubic,
				);
			} else {
				openAuth(showLogin: false);
			}
		}

		return Scaffold(
			backgroundColor: const Color(0xFFF7F5FB),
			body: SafeArea(
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 22),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							const SizedBox(height: 18),
							Align(
								alignment: Alignment.centerRight,
								child: TextButton(
									onPressed: () => openAuth(showLogin: true),
									child: Text(
										'Skip',
										style: TextStyle(
											color: Colors.black.withValues(alpha: 0.6),
											fontWeight: FontWeight.w600,
										),
									),
								),
							),
							const SizedBox(height: 12),
							SizedBox(
								height: 360,
								child: PageView.builder(
									controller: _controller,
									itemCount: _pages.length,
									onPageChanged: (value) => setState(() => _index = value),
									itemBuilder: (context, pageIndex) {
										final page = _pages[pageIndex];
										return Column(
											children: [
												Container(
													height: 220,
													decoration: BoxDecoration(
														color: Colors.white,
														borderRadius: BorderRadius.circular(24),
														boxShadow: [
															BoxShadow(
																color: Colors.black.withValues(alpha: 0.08),
																blurRadius: 16,
																offset: const Offset(0, 8),
															),
														],
													),
													child: Center(
														child: Icon(
															page.icon,
															color: brandColor,
															size: 96,
														),
													),
												),
												const SizedBox(height: 24),
												Text(
													page.title,
													textAlign: TextAlign.center,
													style: const TextStyle(
														fontSize: 24,
														fontWeight: FontWeight.w700,
													),
												),
												const SizedBox(height: 10),
												Text(
													page.description,
													textAlign: TextAlign.center,
													style: TextStyle(
														color: Colors.black.withValues(alpha: 0.6),
														fontSize: 14,
														height: 1.5,
													),
												),
											],
										);
									},
								),
							),
							const SizedBox(height: 8),
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: List.generate(
									_pages.length,
									(dotIndex) => Padding(
										padding: const EdgeInsets.symmetric(horizontal: 3),
										child: _Dot(
											isActive: dotIndex == _index,
											color: brandColor,
										),
									),
								),
							),
							const Spacer(),
							ElevatedButton(
								onPressed: handlePrimaryAction,
								style: ElevatedButton.styleFrom(
									backgroundColor: brandColor,
									foregroundColor: Colors.white,
									padding: const EdgeInsets.symmetric(vertical: 16),
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(16),
									),
									textStyle: const TextStyle(
										fontSize: 16,
										fontWeight: FontWeight.w600,
									),
								),
								child:
										Text(_index == _pages.length - 1 ? 'Get Started' : 'Next'),
							),
							const SizedBox(height: 12),
							OutlinedButton(
								onPressed: () => openAuth(showLogin: true),
								style: OutlinedButton.styleFrom(
									foregroundColor: brandColor,
									side: BorderSide(color: brandColor.withValues(alpha: 0.5)),
									padding: const EdgeInsets.symmetric(vertical: 16),
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(16),
									),
									textStyle: const TextStyle(
										fontSize: 16,
										fontWeight: FontWeight.w600,
									),
								),
								child: const Text('Log In'),
							),
							const SizedBox(height: 18),
						],
					),
				),
			),
		);
	}
}

class _LandingPageData {
	const _LandingPageData({
		required this.icon,
		required this.title,
		required this.description,
	});

	final IconData icon;
	final String title;
	final String description;
}

class _Dot extends StatelessWidget {
	const _Dot({required this.isActive, required this.color});

	final bool isActive;
	final Color color;

	@override
	Widget build(BuildContext context) {
		return AnimatedContainer(
			duration: const Duration(milliseconds: 250),
			height: 8,
			width: isActive ? 22 : 8,
			decoration: BoxDecoration(
				color: isActive ? color : color.withValues(alpha: 0.25),
				borderRadius: BorderRadius.circular(8),
			),
		);
	}
}
